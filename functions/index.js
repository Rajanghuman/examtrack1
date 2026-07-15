const {setGlobalOptions} = require("firebase-functions");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const GROQ_API_KEY = defineSecret("GROQ_API_KEY");

setGlobalOptions({maxInstances: 10});

// ── Existing function (unchanged) ─────────────────────────────
exports.archiveDeclaredResultJobs = onSchedule(
    {
      schedule: "every day 03:00",
      timeZone: "Asia/Kolkata",
    },
    async (event) => {
      logger.info("Starting daily archive sweep for declared-result jobs.");
      const jobsRef = db.collection("jobs");
      const snapshot = await jobsRef
          .where("resultStatus", "==", "declared")
          .get();
      if (snapshot.empty) {
        logger.info("No jobs with declared results found.");
        return;
      }
      logger.info(`Found ${snapshot.size} job(s) to archive.`);
      const docs = snapshot.docs;
      const chunkSize = 250;
      let archivedCount = 0;
      for (let i = 0; i < docs.length; i += chunkSize) {
        const chunk = docs.slice(i, i + chunkSize);
        const batch = db.batch();
        for (const doc of chunk) {
          const data = doc.data();
          const closedJobRef = db.collection("closed_jobs").doc(doc.id);
          batch.set(closedJobRef, {
            ...data,
            archivedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          batch.delete(doc.ref);
          archivedCount++;
        }
        await batch.commit();
        logger.info(`Committed batch of ${chunk.length} job(s).`);
      }
      logger.info(`Archive complete. Total archived: ${archivedCount}.`);
    },
);

// ── New function: Groq question generator for 1v1 Battle ──────
exports.generateBattleQuestions = onCall(
    {
      secrets: [GROQ_API_KEY],
      timeoutSeconds: 60,
      maxInstances: 10,
    },
    async (request) => {
      // ── Auth check ────────────────────────────────────────────
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to start a battle.",
        );
      }

      const {topic, questionCount, difficulty} = request.data;

      // ── Input validation ──────────────────────────────────────
      if (!topic || typeof topic !== "string" || topic.trim().length === 0) {
        throw new HttpsError("invalid-argument", "A valid topic is required.");
      }
      const validCounts = [5, 10, 15, 20];
      if (!validCounts.includes(questionCount)) {
        throw new HttpsError("invalid-argument",
            "Question count must be 5, 10, 15, or 20.");
      }
      const diff = difficulty || "medium";
      if (!["easy", "medium", "hard"].includes(diff)) {
        throw new HttpsError("invalid-argument",
            "Difficulty must be easy, medium, or hard.");
      }

      logger.info(
          `Generating ${questionCount} ${diff} questions for: ${topic}`,
          {uid: request.auth.uid},
      );

      // ── Build prompt ──────────────────────────────────────────
      const prompt = buildPrompt(topic, questionCount, diff);

      // ── Retry loop with exponential backoff ───────────────────
      let questions = null;
      let lastError = null;

      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const raw = await callGroq(GROQ_API_KEY.value(), prompt);
          const parsed = extractAndParseJSON(raw);
          const validated = validateQuestions(parsed, questionCount);

          if (validated) {
            questions = validated;
            logger.info(`Groq succeeded on attempt ${attempt}.`);
            break;
          } else {
            logger.warn(`Attempt ${attempt}: Invalid question set. Retrying.`);
          }
        } catch (err) {
          lastError = err;
          logger.warn(`Attempt ${attempt} failed: ${err.message}.`);
          if (attempt < 3) await sleep(2000 * attempt);
        }
      }

      // ── Fallback to Firestore bank ────────────────────────────
      if (!questions) {
        logger.warn(`Groq failed. Using fallback for: ${topic}.`);
        questions = await getFallbackQuestions(topic, questionCount);
        if (!questions) {
          throw new HttpsError("internal",
              "Could not generate questions. Please try again.");
        }
      } else {
        // Only shuffle Groq-generated questions — fallback bank
        // questions are presumably already reviewed/correct as-is,
        // so we leave those untouched.
        questions = shuffleAllQuestions(questions, "correctIndex");
      }

      return {
        questions,
        topic,
        generatedAt: new Date().toISOString(),
        source: lastError ? "fallback" : "groq",
      };
    },
);

// ================================================================
// COMPREHENSIVE EXAM-AWARE PROMPT BUILDER FOR GROQ
// Covers every exam in ExamTrack with full syllabus knowledge
// and PYQ-based question style calibration
// ================================================================

function buildPrompt(topic, count, difficulty) {

  // ── Difficulty calibration ───────────────────────────────────
  const difficultyMap = {
    easy: {
      desc: "Easy — basic factual questions that 70%+ aspirants who have studied the basics should get correct",
      style: "Direct recall questions from standard textbooks. Clear, unambiguous. Options should have one obviously correct answer for a well-prepared student.",
      example: "Q: What is the capital of Punjab? [Direct fact, basic level]"
    },
    medium: {
      desc: "Medium — same difficulty as the actual exam paper. 40-60% of well-prepared aspirants should get correct",
      style: "Application-based and fact-based questions mixed. Options must all be plausible — a student who hasn't studied specifically cannot guess easily.",
      example: "Q: Which article of the Indian Constitution provides for the establishment of a Finance Commission? [Requires specific preparation]"
    },
    hard: {
      desc: "Hard — challenging questions that only 20-35% of aspirants get correct. Tests deep knowledge",
      style: "Less-commonly tested facts, application questions, tricky options that are very similar to each other. A student must have done thorough preparation.",
      example: "Q: Under which schedule of the Indian Constitution are the forms of oaths and affirmations prescribed? [Requires deep constitutional knowledge]"
    }
  };

  const diff = difficultyMap[difficulty] || difficultyMap.medium;

  // ── Detect exam type from topic ──────────────────────────────
  const topicLower = topic.toLowerCase();

  // Detect all topics selected
  const topics = topic.split(',').map(t => t.trim());
  const isMultiTopic = topics.length > 1;

  // Individual exam detectors
  const isPunjabPolice = topicLower.includes('punjab police');
  const isHaryanaPolice = topicLower.includes('haryana police');
  const isUPPolice = topicLower.includes('up police');
  const isSSCCGL = topicLower.includes('ssc cgl');
  const isSSCCHSL = topicLower.includes('ssc chsl');
  const isSSCGD = topicLower.includes('ssc gd');
  const isSSCMTS = topicLower.includes('ssc mts');
  const isSSC = topicLower.includes('ssc');
  const isIBPSPO = topicLower.includes('ibps po');
  const isIBPSClerk = topicLower.includes('ibps clerk');
  const isSBIPO = topicLower.includes('sbi po');
  const isSBIClerk = topicLower.includes('sbi clerk');
  const isBanking = isIBPSPO || isIBPSClerk || isSBIPO || isSBIClerk || topicLower.includes('bank');
  const isRRBNTPC = topicLower.includes('rrb ntpc');
  const isRRBALP = topicLower.includes('rrb alp');
  const isRailway = isRRBNTPC || isRRBALP || topicLower.includes('railway') || topicLower.includes('rrb');
  const isUPSC = topicLower.includes('upsc');
  const isNDA = topicLower.includes('nda');

  // Subject detectors
  const isGK = topicLower.includes('general knowledge') || topicLower.includes('gk');
  const isCurrentAffairs = topicLower.includes('current affairs');
  const isMaths = topicLower.includes('math') || topicLower.includes('quantitative') || topicLower.includes('aptitude');
  const isReasoning = topicLower.includes('reasoning') || topicLower.includes('mental ability');
  const isEnglish = topicLower.includes('english');
  const isHistory = topicLower.includes('history');
  const isGeography = topicLower.includes('geography');
  const isPolity = topicLower.includes('polity') || topicLower.includes('constitution');
  const isScience = topicLower.includes('science');
  const isPunjabGK = topicLower.includes('punjab gk');
  const isEconomy = topicLower.includes('economics') || topicLower.includes('economy');

  // ── Exam-specific deep knowledge ────────────────────────────
  let examKnowledge = '';

  if (isPunjabPolice) {
    examKnowledge = `
EXAM: Punjab Police Constable (PSSSB)
PAPER PATTERN: Paper 1 (100Q, 100 marks, 2 hrs, no negative marking)
- General Awareness: 35 questions (35 marks) ← HIGHEST WEIGHT
- Quantitative Aptitude & Numerical Ability: 20 questions
- Mental Ability & Logical Reasoning: 20 questions
- English Language: 10 questions
- Digital Literacy: 5 questions
- Punjabi Language: 10 questions

WHAT ACTUALLY COMES IN THE EXAM (based on PYQs 2021-2025):
General Awareness (most important for this exam):
- Punjab Sikh History: 10 Sikh Gurus (names, contributions, birthplaces, battles), Sikh Misls, Maharaja Ranjit Singh's empire, Battle of Chamkaur (1704), Battle of Anandpur Sahib, Jallianwala Bagh massacre (1919), Operation Blue Star (1984), Punjab Reorganization (1966)
- Punjab Geography: 5 rivers (Sutlej, Beas, Ravi, Chenab, Jhelum), 23 districts of Punjab, border states, Bhakra Nangal Dam, Shahpur Kandi Dam, Punjab-Haryana Canal disputes (SYL)
- Punjab Culture: Bhangra, Giddha, Phulkari, Jutti, Patola, Gurpurab, Baisakhi, Lohri, Teej, folk music instruments (Dhol, Tumbi, Algoza, Chimta), Punjabi poets (Bulleh Shah, Waris Shah, Shiv Kumar Batalvi)
- Punjab Government & Politics: CM, Governor, number of Lok Sabha/Rajya Sabha seats, SGPC, Shiromani Akali Dal history
- Indian Constitution: Articles 14-32 (Fundamental Rights), Directive Principles (Articles 36-51), 73rd/74th Amendment (Panchayati Raj), Article 356 (President's Rule), Article 370 (J&K)
- Important Days: Punjab specific + national
- Sports: Punjab in Olympics, Milkha Singh, P.T. Usha connection, recent Olympic medals by Punjab athletes
- Awards: Padma awards to Punjab personalities

Quantitative Aptitude (actual PYQ level):
- Percentage, Profit-Loss, Simple/Compound Interest, Time & Work, Speed-Distance, Ratio & Proportion
- Simple calculation questions, no complex algebra
- Numbers up to 4 digits, fractions, basic mensuration (area of rectangle, circle)

Mental Ability (actual PYQ level):
- Series completion (number & letter)
- Coding-Decoding (simple letter shift +1/+2)
- Blood Relations
- Directions (4-direction problems)
- Ranking
- Simple analogy
- Odd one out

Digital Literacy (actual PYQ level):
- Basic computer parts (RAM, ROM, CPU, Monitor)
- MS Office (common shortcuts: Ctrl+C, Ctrl+V, Ctrl+S, F12)
- Internet basics (URL, browser, email)
- Cybersecurity basics (phishing, virus)
- UPI, Digital India scheme
`;
  }

  else if (isHaryanaPolice) {
    examKnowledge = `
EXAM: Haryana Police Constable (HSSC)
PAPER PATTERN: Written exam 100Q, 97 marks weightage, OMR based
NOTE: No marks deducted for wrong answers, BUT 0.97 marks deducted for UNATTEMPTED questions

WHAT ACTUALLY COMES IN THE EXAM:
- Haryana GK: History (Haryana in 1857 revolt, formation of Haryana in 1966), Geography (22 districts, Aravalli hills, rivers), Culture (Phag dance, Saang, Rasiya music, Haryanvi cuisine)
- Haryana CM and Governors history, Haryana schemes (Beti Bachao campaign started from Panipat)
- Indian History: Freedom struggle, 1857 revolt, major battles, important personalities
- Indian Polity: Constitution basics, President, PM, Governor powers
- General Science: Physics and Biology at 10th level
- Mathematics: Basic arithmetic — exactly same type as Punjab Police
- Reasoning: Same pattern as Punjab Police
- Computer basics: Same as Punjab Police
`;
  }

  else if (isUPPolice) {
    examKnowledge = `
EXAM: UP Police Constable (UPPRPB)
PAPER PATTERN: 150Q, 300 marks (2 marks each), NO negative marking, offline OMR

WHAT ACTUALLY COMES IN THE EXAM (based on 2024 PYQ):
General Knowledge (38Q - highest weight):
- UP specific: 75 districts of UP, UP rivers (Ganga, Yamuna, Gomti, Saryu), UP culture, CM history, UP schemes, Kumbh Mela (Prayagraj), Taj Mahal (Agra), major UP cities
- Indian History: Freedom struggle, Congress sessions, important personalities
- Indian Geography: States, capitals, rivers, national parks
- Indian Polity: Constitutional articles, President, Parliament

General Hindi (37Q):
- Hindi grammar: Sandhi, Samas, Alankar, Ras, Muhavare, Lokoktiyan
- Fill in blanks, error detection in Hindi

Numerical & Mental Ability (38Q):
- Percentage, Profit-Loss, SI/CI, Time-Work, Speed-Distance, Average
- Simple to medium difficulty calculations

Reasoning (37Q):
- Series, Analogy, Coding-Decoding, Blood Relations, Direction, Ranking, Venn Diagrams
`;
  }

  else if (isSSCCGL) {
    examKnowledge = `
EXAM: SSC CGL (Staff Selection Commission Combined Graduate Level)
PAPER PATTERN: Tier 1 = 100Q, 200 marks, 60 mins, -0.5 per wrong, SECTIONAL TIMING (15 mins each section)
4 sections: General Intelligence & Reasoning (25Q), General Awareness (25Q), Quantitative Aptitude (25Q), English Comprehension (25Q)

WHAT ACTUALLY COMES IN THE EXAM (based on PYQs 2019-2025):

General Intelligence & Reasoning (25Q — most scoring):
- Matrix/Figure based questions: Mirror image, Water image, Paper folding, Hidden figures
- Verbal: Analogy, Classification, Series (Number, Letter, Mixed), Coding-Decoding (new pattern — row arrangement)
- Venn Diagrams, Blood Relations (coded), Directions, Calendar, Clock
- Statement-Conclusion, Syllogism (less common in Tier 1)
- INPUT-OUTPUT machine (common in Tier 2 but appears in Tier 1 occasionally)

General Awareness (25Q — most static GK in pattern):
- History: Medieval India (Mughals, Sultanate), Freedom struggle (1857, 1942 Quit India, Gandhi's movements), Ancient India (Maurya, Gupta empires)
- Geography: Indian rivers, mountains, passes, soils, national parks, wildlife sanctuaries, world geography
- Polity: Constitutional articles (especially Fundamental Rights 12-35), Parliament structure, Schedules, Amendments
- Economy: Five Year Plans, NITI Aayog, RBI functions, Budget terms (Fiscal deficit, Revenue deficit), GST, Banking reforms
- Science: Physics (Unit of force/pressure/work), Chemistry (Chemical formulas, acids-bases), Biology (Cell organelles, Human diseases)
- Current Affairs: Last 6 months — national/international awards, appointments, schemes
- Static GK: National symbols, Important days, UNESCO heritage sites in India, Books & Authors

Quantitative Aptitude (25Q):
- Data Interpretation: 5Q from table/bar/pie chart
- Arithmetic: Percentage, Profit-Loss, CI/SI, Ratio, Average, Time-Work, Speed-Distance (2-3Q each)
- Algebra: Quadratic equations, Identities (a+b)², (a-b)², a³+b³
- Geometry: Triangles (properties, similarity), Circles (tangent, chord), Mensuration (cone, cylinder, sphere)
- Trigonometry: sin/cos/tan values, Height-Distance (2Q)
- Number System: LCM, HCF, Remainders, Simplification

English Comprehension (25Q):
- Reading Comprehension: 1 passage, 5Q
- Cloze Test (Fill in blanks): 5-10Q
- Error Spotting: 2-3Q
- Sentence Improvement: 2-3Q
- Para Jumbles: 5Q
- Synonyms/Antonyms: 2-3Q
- One Word Substitution: 2-3Q
- Idioms & Phrases: 1-2Q
`;
  }

  else if (isSSCCHSL) {
    examKnowledge = `
EXAM: SSC CHSL (Combined Higher Secondary Level)
PAPER PATTERN: Same as SSC CGL Tier 1 but 12th pass level, slightly easier
Posts: LDC, JSA, DEO, PA/SA

WHAT ACTUALLY COMES (based on PYQs):
- Same pattern as SSC CGL but easier difficulty
- More static GK, less current affairs
- Maths: 10th-12th level — Mensuration, Trigonometry, basic DI
- Reasoning: Similar to CGL but simpler
- English: More vocabulary-based, simpler RC passages
- GA: Same topics as CGL but easier questions
`;
  }

  else if (isSSCGD) {
    examKnowledge = `
EXAM: SSC GD Constable (General Duty)
PAPER PATTERN: 80Q, 160 marks, 60 mins, -0.5 per wrong
4 sections: Intelligence & Reasoning (20Q), General Knowledge (20Q), Elementary Mathematics (20Q), English/Hindi (20Q)

WHAT ACTUALLY COMES (based on PYQs 2021-2024):
- Reasoning: Very basic — simple series, analogy, coding-decoding, blood relations
- GK: National symbols, important days, capitals, freedom fighters, basic polity, science (10th level)
- Mathematics: Very basic arithmetic — percentage, profit-loss, SI, average, time-speed. No algebra or advanced topics.
- English/Hindi: Basic grammar, fill in blanks, simple vocabulary
- Difficulty: Easier than SSC CGL — 10th pass standard
`;
  }

  else if (isBanking) {
    examKnowledge = `
EXAM: ${isIBPSPO ? 'IBPS PO' : isIBPSClerk ? 'IBPS Clerk' : isSBIPO ? 'SBI PO' : 'SBI Clerk'} (Banking exam)
PAPER PATTERN (Prelims): 100Q, 60 mins, -0.25 per wrong, SECTIONAL TIMING
- English Language: 30Q, 20 mins
- Quantitative Aptitude: 35Q, 20 mins  
- Reasoning Ability: 35Q, 20 mins

WHAT ACTUALLY COMES (based on PYQs 2022-2025):

Reasoning Ability (35Q — most important for banking):
- Puzzles & Seating Arrangement: 3-4 sets (15-20Q) — Floor puzzle, Linear arrangement, Circular seating (facing/not facing), Box puzzle, Month-Year puzzle
- Inequalities: 5Q — Coded inequalities (A @ B means A > B etc.)
- Syllogism: 3-5Q — All/Some/No type with possibility cases
- Blood Relations: 2-3Q (coded blood relations: "P%Q means P is mother of Q")
- Coding-Decoding: New pattern (row arrangement, 5 words encoded together)
- Direction-Distance: 2-3Q
- Alphanumeric Series: 2-3Q
- Data Sufficiency: 2-3Q

Quantitative Aptitude (35Q):
- Data Interpretation: 10-15Q — Table, Bar graph, Line chart, Pie chart, Caselet
- Number Series: 5Q — Find missing/wrong term
- Quadratic Equations: 5Q — Compare roots of two equations
- Arithmetic: 10-15Q — Percentage, Profit-Loss, SI/CI, Time-Work, Speed-Distance, Boats-Streams, Pipes-Cisterns, Mixture-Alligation, Partnership, Average

Banking GA (for Mains):
- RBI: Repo rate, Reverse repo, CRR, SLR, MSF, Bank rate — current values
- Banking: Types of accounts (CASA, NRI, FD), NEFT/RTGS/IMPS/UPI limits and timings
- Government schemes: PM Jan Dhan, PMMY (Mudra), Suraksha Bima, Jeevan Jyoti
- Recent banking mergers, Basel norms, SARFAESI Act, IBC Code
- Financial institutions: NABARD, SIDBI, NHB, EXIM Bank
- Insurance: IRDA, LIC premium products
- Capital markets: SEBI, NSE/BSE, Sensex/Nifty index stocks
`;
  }

  else if (isRailway) {
    examKnowledge = `
EXAM: ${isRRBNTPC ? 'RRB NTPC' : 'RRB ALP/Technician'} (Railway Recruitment Board)
PAPER PATTERN (CBT 1): 100Q, 90 mins, -1/3 per wrong
- Mathematics: 30Q
- General Intelligence & Reasoning: 30Q
- General Awareness: 40Q

WHAT ACTUALLY COMES (based on PYQs 2020-2025):

General Awareness (40Q — highest weight, most important for railways):
- Railway-specific GK: First railway in India (1853, Bombay to Thane, by Lord Dalhousie), Railway zones and HQs (16 zones), Railway Minister, National Rail Plan, Vande Bharat Express, bullet train project
- Indian History: Ancient (Indus Valley, Maurya, Gupta), Medieval (Delhi Sultanate, Mughals), Modern (1857 Revolt, Congress formation, Gandhi's movements, Independence)
- Indian Geography: Rivers (source, tributaries), States-Capitals, National Parks, soil types, crops, minerals
- Indian Polity: Constitution, fundamental rights, articles, President/PM/Governor powers, Parliament sessions
- Indian Economy: Five Year Plans, GDP, RBI, government schemes
- Science: Physics (units, Newton's laws, electricity, light), Chemistry (elements, periodic table, common reactions), Biology (cell, human body systems, common diseases)
- Computer basics: History, hardware, software, MS Office
- Current Affairs: Sports, awards, appointments, national/international events (last 6 months)
- Sports: Olympics, Cricket World Cup, National sports awards (Arjuna, Khel Ratna)

Mathematics (30Q):
- Same as SSC level but slightly easier
- No geometry or trigonometry — focus on arithmetic
- Simplification, Number System, Percentage, Profit-Loss, SI/CI, Ratio, Time-Work, Speed-Distance, Pipes-Cisterns, Average, LCM-HCF, Square roots

Reasoning (30Q):
- Analogy, Classification, Series, Coding-Decoding, Blood Relations, Directions, Calendar, Clock, Puzzles (simpler than banking), Venn Diagrams, Syllogism, Statement-Conclusion, Non-verbal (Mirror image, Water image, Figure series)
`;
  }

  else if (isGK || isHistory || isGeography || isPolity || isScience || isCurrentAffairs || isEconomy || isPunjabGK) {
    examKnowledge = `
SUBJECT: ${topic} for Indian Competitive Exams
TARGET EXAMS: SSC CGL, IBPS PO, RRB NTPC, Punjab Police, UP Police

${isHistory ? `HISTORY focus areas (PYQ-based):
- Ancient India: Indus Valley Civilisation, Vedic period, Maurya Empire (Chandragupta, Ashoka), Gupta Empire (Golden Age), Sangam period
- Medieval India: Delhi Sultanate (Slave dynasty, Khilji, Tughlaq, Sayyid, Lodi), Mughal Empire (Babur to Aurangzeb, key battles — Panipat 1526/1556/1761)
- Modern India: British colonization, Revolt of 1857, Indian National Congress formation (1885), Partition of Bengal (1905), Jallianwala Bagh (1919), Non-Cooperation (1920), Civil Disobedience (1930), Quit India (1942), Independence (1947)
- Important: Focus on questions that actually appeared in SSC PYQs` : ''}

${isGeography ? `GEOGRAPHY focus areas (PYQ-based):
- Indian rivers: origin, tributaries, states they flow through, dams on them
- Mountains: Himalayan ranges, peaks, passes
- Indian states: capitals, borders, languages
- Climate: Monsoon, seasons, rainfall patterns
- Soils: Alluvial, Black, Red, Laterite — where found, crops grown
- National Parks and Wildlife Sanctuaries: animals found there
- World Geography: oceans, continents, countries, important rivers` : ''}

${isPolity ? `POLITY focus areas (PYQ-based):
- Most commonly tested articles: Art.14 (Equality), Art.19 (Six freedoms), Art.21 (Life & Liberty), Art.32 (Constitutional Remedies), Art.51A (Fundamental Duties), Art.243 (Panchayati Raj), Art.280 (Finance Commission), Art.352 (National Emergency), Art.356 (President's Rule), Art.360 (Financial Emergency)
- Schedules: 1st (States/UTs), 2nd (Salaries), 3rd (Oaths), 4th (Rajya Sabha seats), 5th (Scheduled Areas), 6th (Tribal Areas), 7th (Union/State/Concurrent lists), 8th (Official languages), 9th (Land reforms), 10th (Anti-defection), 11th (Panchayat subjects), 12th (Municipality subjects)
- Parliament: Lok Sabha (552 max seats), Rajya Sabha (250 max), Joint session (Art.108)
- Amendment procedure: Art.368
- Constitutional bodies: CAG, Election Commission, UPSC, Finance Commission` : ''}

${isCurrentAffairs ? `CURRENT AFFAIRS focus (2024-2026):
- National: Government schemes (PM Awas 2.0, Jal Jeevan Mission, PM Kisan, Ayushman Bharat), Budget highlights, new laws passed by Parliament
- International: G20 presidency, SCO summits, BRICS expansion, India-Pakistan border updates
- Awards: Bharat Ratna (2024-26 recipients), Nobel Prize winners, Padma awards to Punjab personalities
- Sports: Paris Olympics 2024 (India's medals), Cricket World Cup 2024, Asian Games 2023
- Appointments: New CBI Director, ED Director, RBI Governor, Army Chief, CAG
- Space: ISRO missions (Chandrayaan, Gaganyaan updates, Aditya-L1)
- Economy: GDP growth rate, inflation figures, RBI policy rates (repo rate current value)` : ''}

${isPunjabGK ? `PUNJAB GK focus areas:
- Sikh Gurus: All 10 Gurus — birth, death, key contributions, Gurdwaras associated with them
- Sikh history: Sikh Misls (12 Misls), Maharaja Ranjit Singh (capital Lahore, period 1801-1839), Anglo-Sikh Wars (1845-46, 1848-49), Kohinoor diamond
- Punjab history: Jallianwala Bagh (April 13, 1919, General Dyer, Udham Singh), Bhagat Singh (Banga village, martyred March 23, 1931), SGPC formation (1920), Akali movement
- Modern Punjab: Formation November 1, 1966 (Punjab Reorganisation Act), Chandigarh as joint capital, SYL canal dispute, Operation Blue Star (June 1984)
- Punjab geography: Rivers, 23 districts, Shiwalik hills, border with Pakistan, Bhakra Nangal Dam (Sutlej river, Bilaspur HP)
- Culture: Bhangra, Giddha, Phulkari (needlework), Jutti (footwear), Patola (weaving), Punjabi cuisine, instruments` : ''}
`;
  }

  else if (isMaths) {
    examKnowledge = `
SUBJECT: Quantitative Aptitude / Mathematics for Indian Competitive Exams

IMPORTANT RULES FOR MATHS QUESTIONS:
1. VERIFY YOUR OWN CALCULATIONS — every answer must be mathematically correct
2. Use clean numbers (avoid decimals like 3.7km or ₹847.32 — use round numbers)
3. All amounts in Indian Rupees (₹)
4. Difficulty calibration:
   - Easy: 1-2 step calculations, simple fractions, basic percentage
   - Medium: 2-3 step problems, typical SSC/Banking level
   - Hard: Multi-step problems, advanced concepts, tricky options

TOPICS (PYQ frequency based):
HIGH FREQUENCY: Percentage, Profit-Loss-Discount, Simple Interest, Compound Interest, Time & Work, Time-Speed-Distance, Ratio & Proportion, Average
MEDIUM FREQUENCY: Pipes & Cisterns, Trains, Boats & Streams, Partnership, Mixture & Alligation, Number System (LCM, HCF, Divisibility)
LOWER FREQUENCY: Permutation-Combination, Probability, Mensuration (Area, Volume), Trigonometry, Algebra

WRONG OPTIONS must be: close to the correct answer (common calculation mistakes), results of applying wrong formulas, or results of using different but plausible values.
`;
  }

  else if (isReasoning) {
    examKnowledge = `
SUBJECT: Reasoning / Mental Ability for Indian Competitive Exams

IMPORTANT RULES FOR REASONING QUESTIONS:
1. Every reasoning question must have ONE UNAMBIGUOUS correct answer
2. The logic must be clear — no questions where multiple answers could be justified
3. For series questions: the pattern must be clearly identifiable

TOPIC DISTRIBUTION (PYQ frequency):
HIGH FREQUENCY: Puzzles & Seating Arrangement (for banking), Series (Number/Letter/Mixed), Analogy, Coding-Decoding, Blood Relations
MEDIUM FREQUENCY: Directions & Distance, Ranking & Order, Syllogism, Venn Diagrams, Statement-Conclusion
LOWER FREQUENCY: Input-Output (banking), Calendar & Clock, Data Sufficiency, Non-verbal (Mirror image, Paper folding)

CODING-DECODING patterns (common in exams):
- Letter shift: Each letter +1 or +2 in alphabet
- Symbol coding: A=1, B=2 type
- New pattern: 5 words coded together in a row

SERIES patterns (common in exams):
- Multiplication: ×2, ×3
- Addition with increasing difference: +1, +2, +3
- Prime number series
- Squares/Cubes: 1, 4, 9, 16 or 1, 8, 27, 64
- Mixed operations: +2, ×3, +2, ×3
`;
  }

  else if (isEnglish) {
    examKnowledge = `
SUBJECT: English Language for Indian Competitive Exams
TARGET EXAMS: SSC CGL, IBPS PO, RRB NTPC, Punjab Police, UP Police

ENGLISH TOPIC DISTRIBUTION (PYQ frequency):

Reading Comprehension (RC):
- 1 passage of 150-300 words on social/economic/environmental topics
- Questions: Main idea, Vocabulary in context, Inference, Author's tone
- RC passages in SSC use formal English, Banking uses financial/social topics

Error Spotting / Error Detection:
- Find grammatical error in one of 4 parts of a sentence
- Common errors: Subject-Verb agreement, Tense errors, Preposition misuse, Article (a/an/the) errors, Pronoun reference errors
- Example: "Each of the boys (A) / have completed (B) / their homework (C) / on time (D)" — Error in B (should be 'has completed')

Fill in the Blanks / Cloze Test:
- Choose correct word/phrase from options
- Test: Prepositions (in/on/at/for), Articles (a/an/the), Conjunctions, Tense consistency, Vocabulary
- Cloze Test: A passage with 5-10 blanks, choose from given options for each blank

Synonyms and Antonyms (important for SSC/Banking):
- Test vocabulary used in formal/business/literary context
- Common SSC words: Loquacious, Verbose, Taciturn, Perspicacious, Mendacious, Alacrity, Beguile, Candid, Diligent, Ephemeral
- Focus on words that commonly appear in English newspapers

One Word Substitution:
- "A person who does not believe in God" = Atheist
- "A place where books are kept" = Library
- "Fear of water" = Hydrophobia
- "One who walks in sleep" = Somnambulist

Idioms and Phrases:
- "Bite the bullet" = To endure a painful situation
- "Beat around the bush" = To avoid the main topic
- "Let the cat out of the bag" = To reveal a secret
- "Hit the nail on the head" = To describe exactly what is causing a situation

Para Jumbles:
- 5-6 sentences to rearrange into a logical paragraph
- Look for: Opening sentence (topic introduction), Connecting words (However, Therefore, Moreover, Thus), Concluding sentence

Active/Passive Voice:
- Active: Subject does the action
- Passive: Subject receives the action
- "Ram ate the apple" (Active) = "The apple was eaten by Ram" (Passive)

Direct/Indirect Speech:
- "He said, 'I am happy'" = He said that he was happy
- Rules: Change of pronoun, change of tense (present→past), change of time expressions

DIFFICULTY CALIBRATION for English:
- Easy: Basic grammar (fill in blanks with simple verbs), common synonyms/antonyms, simple one-word substitution
- Medium: Error spotting in complex sentences, RC with inference questions, idioms and phrases
- Hard: Advanced vocabulary (rare words), complex error spotting, sophisticated RC with critical reasoning
`;
  }

  else if (isGK) {
    examKnowledge = `
SUBJECT: General Knowledge for Indian Competitive Exams
TARGET EXAMS: SSC CGL, RRB NTPC, Punjab Police, UPSC Prelims, Banking

GENERAL KNOWLEDGE TOPIC DISTRIBUTION (PYQ frequency based):

Indian History (30% of GK questions in exams):
- Ancient India: Indus Valley (Harappa-Mohenjo-daro, key features), Vedic period (Rig Veda, Sabha-Samiti), Maurya Empire (Chandragupta, Chanakya, Ashoka-edicts), Gupta Empire (Golden Age, Kalidasa, Aryabhatta), Sangam period (Tamil kingdoms)
- Medieval India: Delhi Sultanate (Qutub-ud-din Aibak, Alauddin Khilji-market reforms, Muhammad bin Tughlaq, Firoz Shah Tughlaq), Mughal Empire (Babur-Battle of Panipat 1526, Akbar-Din-i-Ilahi/Navratnas, Shah Jahan-Taj Mahal, Aurangzeb-Alamgir), Bhakti movement (Kabir, Mirabai, Tukaram, Ramananda), Sufi movement (Chishti, Suhrawardi orders)
- Modern India: British East India Company, Subsidiary Alliance (Wellesley), Doctrine of Lapse (Dalhousie), Revolt of 1857 (causes, centres, leaders — Mangal Pandey, Rani Laxmibai, Tantia Tope, Bahadur Shah Zafar), Indian National Congress (1885, A.O. Hume, Dadabhai Naoroji), Partition of Bengal 1905, Swadeshi movement, Morley-Minto Reforms 1909, Rowlatt Act 1919, Jallianwala Bagh, Non-Cooperation Movement 1920, Civil Disobedience Movement 1930 (Dandi March), Quit India Movement 1942, INA (Subhash Chandra Bose, Azad Hind Fauj)

Geography (25% of GK):
- Indian rivers: Ganga (Gangotri → Bay of Bengal), Yamuna (Yamunotri), Brahmaputra (Tibet-Arunachal), Indus system (Jhelum, Chenab, Ravi, Beas, Sutlej), Peninsular rivers (Mahanadi, Godavari, Krishna, Cauvery — west to east)
- Mountain ranges: Greater Himalayas, Lesser Himalayas (Pir Panjal), Siwaliks, Vindhya, Satpura, Western Ghats, Eastern Ghats
- Important passes: Nathu La (Sikkim), Shipki La (HP), Rohtang (HP), Banihal (J&K), Khyber Pass (Afghanistan-Pakistan)
- National Parks: Jim Corbett (1st, Uttarakhand), Kaziranga (Assam, one-horned rhino), Sundarbans (Bengal, tigers), Gir (Gujarat, Asiatic lions), Ranthambore (Rajasthan, tigers), Periyar (Kerala, elephants), Dachigam (J&K, hangul deer)
- Dams: Bhakra Nangal (Sutlej, HP-Punjab), Hirakud (Mahanadi, Odisha), Nagarjuna Sagar (Krishna, AP-Telangana), Tehri (Bhagirathi, Uttarakhand), Sardar Sarovar (Narmada, Gujarat)

Science (20% of GK):
- Physics: Newton's 3 laws, SI units (Force=Newton, Pressure=Pascal, Power=Watt, Work=Joule, Frequency=Hertz), Sound (medium required, ultrasound >20kHz), Light (reflection, refraction, total internal reflection), Electricity (Ohm's law V=IR, series/parallel circuits)
- Chemistry: Periodic table (first 20 elements by symbol), Common acids (HCl, H2SO4, HNO3) and bases (NaOH, Ca(OH)2), Rusting (Fe+O2+H2O), Bleaching powder (Ca(ClO)Cl), Dry ice (solid CO2), Heavy water (D2O)
- Biology: Cell organelles (Mitochondria=powerhouse, Ribosomes=protein synthesis, Chloroplasts=photosynthesis), Blood groups (A, B, AB, O; Rh factor), Vitamins (A=night blindness, B1=beriberi, C=scurvy, D=rickets), Common diseases (Malaria=Plasmodium/mosquito, Tuberculosis=Mycobacterium/air, Typhoid=Salmonella/water)

Awards and Honours (5% of GK):
- Bharat Ratna: India's highest civilian award, given since 1954
- Padma Vibhushan, Padma Bhushan, Padma Shri (in order of precedence)
- Military: Param Vir Chakra (highest), Maha Vir Chakra, Vir Chakra
- Sports: Khel Ratna (highest), Arjuna Award, Dronacharya Award (coaches)
- Nobel Prize: categories, recent Indian-origin winners

Important Days (5% of GK):
- Republic Day: January 26 | Independence Day: August 15 | Gandhi Jayanti: October 2
- National Science Day: February 28 | Teachers Day: September 5 | Children's Day: November 14
- International: World Environment Day June 5, World Health Day April 7, Human Rights Day December 10

GENERATE questions that specifically test facts that appear in actual PYQ papers of SSC/RRB/Police exams.
`;
  }

  else if (isCurrentAffairs) {
    examKnowledge = `
SUBJECT: Current Affairs for Indian Competitive Exams (2024-2026)
TARGET EXAMS: SSC CGL, IBPS PO, RRB NTPC, Punjab Police, UP Police

CURRENT AFFAIRS TOPIC DISTRIBUTION (PYQ frequency):

Government Schemes and Policies (most frequently tested):
- PM Awas Yojana 2.0: Housing for all, urban+rural
- PM Jan Dhan Yojana: Financial inclusion, zero balance accounts
- PM Kisan Samman Nidhi: ₹6000/year to farmers in 3 instalments
- Ayushman Bharat: Health insurance ₹5 lakh/year, PM-JAY
- Jal Jeevan Mission: Tap water to every rural household by 2024
- Swachh Bharat Mission: ODF status, solid waste management
- Make in India: Manufacturing hub, 25 focus sectors
- Digital India: Internet connectivity, digital services
- Startup India: Fund of Funds, tax exemptions for startups
- MUDRA Yojana: Shishu/Kishore/Tarun loans for micro enterprises
- National Education Policy 2020: 5+3+3+4 structure, mother tongue medium

National Awards and Events (2024-2026):
- Bharat Ratna recipients (recent years)
- Padma Awards categories and recent prominent recipients
- Nobel Prize 2024 winners (Peace, Literature, Physics, Chemistry, Medicine, Economics)
- Dadasaheb Phalke Award: Cinema's highest award

Sports (important for exams):
- Paris Olympics 2024: India's medal tally, gold/silver/bronze winners
- T20 World Cup 2024: Winner, venue, India's performance
- Asian Games 2023: India's best-ever performance
- ICC Rankings: Current Test/ODI/T20 top teams
- Khel Ratna 2024 recipients

International Affairs:
- G20: India's presidency ended 2023, what was achieved
- SCO (Shanghai Cooperation Organisation): India's membership, recent summits
- BRICS expansion: New members joining 2024
- India-Pakistan relations: Current border status
- India-China relations: LAC updates, Galwan Valley aftermath

Science and Technology:
- ISRO missions: Chandrayaan-3 (Moon landing August 2023), Aditya-L1 (Sun study), Gaganyaan (human spaceflight preparation)
- Semiconductor plants in India: upcoming fabs
- Digital Rupee (CBDC): RBI's pilot, current status
- 5G rollout in India: Jio and Airtel coverage

Economy and Finance:
- India's GDP growth rate (2024-25)
- Repo rate: Current value as set by RBI MPC
- India's rank in Global Innovation Index, Ease of Doing Business
- Budget 2025-26 highlights: Key allocations, new schemes
- GST collection records

Punjab and North India specific current affairs:
- Punjab government schemes (Chief Minister's announcements)
- Haryana developments
- New industrial projects in North India
- Sports achievements by Punjab athletes

IMPORTANT: Generate questions on verifiable recent facts only. If a specific date/number might have changed recently, frame the question in a way that tests the concept rather than a specific current figure.
`;
  }

  else {
    examKnowledge = `
TOPIC: \${topic}
For Indian competitive government exams (SSC, Banking, Railway, Police)

Apply general Indian exam standards:
- Use Indian context throughout (₹ for money, Indian cities, Indian examples)
- Questions should match the pattern of Indian government exams
- Mix of recall and application questions
- All options must be plausible — no obviously wrong choices
`;
  }

  // ── Multi-topic instruction ──────────────────────────────────
  const topicInstruction = isMultiTopic
    ? `SELECTED TOPICS: ${topic}
Distribute ${count} questions proportionally across all selected topics (approximately ${Math.ceil(count/topics.length)} questions per topic).`
    : `TOPIC: ${topic}`;

  // ── Final assembled prompt ───────────────────────────────────
  return `You are India's most experienced government exam question setter. You have 20 years of experience setting papers for SSC CGL, IBPS PO, RRB NTPC, Punjab Police, UP Police, and UPSC. You have deep knowledge of PYQs (Previous Year Questions) from 2015-2025 and know exactly what these exams actually test.

${topicInstruction}
QUESTIONS NEEDED: ${count}
DIFFICULTY: ${diff.desc}
STYLE: ${diff.style}

${examKnowledge}

UNIVERSAL RULES — FOLLOW STRICTLY:

1. DISTRACTOR QUALITY (this is where most AI fails):
   ✗ BAD: Q: Who wrote the Indian Constitution?
          Options: A) Nehru  B) Gandhi  C) Dr. B.R. Ambedkar  D) Napoleon Bonaparte
          [Napoleon is obviously wrong — no real exam puts such options]
   ✓ GOOD: Q: Dr. B.R. Ambedkar was the Chairman of which committee that drafted the Indian Constitution?
           Options: A) Drafting Committee  B) Constituent Assembly  C) Union Powers Committee  D) Union Constitution Committee
           [All options are real committees — requires actual knowledge]

2. OPTION RULES:
   - All 4 options must be from the SAME CATEGORY (all cities, all names, all numbers, all years, all articles)
   - Wrong options must be commonly confused with the correct answer
   - For numerical answers: wrong options = result of common calculation errors
   - No option should be obviously absurd or irrelevant

3. FACTUAL ACCURACY:
   - ONLY include facts you are 100% certain about
   - Verify Article numbers, years, names before using
   - For current data (GDP, population, rates): use approximate recent values or avoid
   - If unsure about a specific fact — choose a different question

4. QUESTION LANGUAGE:
   - Questions in English (like actual exam papers)
   - Options may include Hindi/Punjabi terms where appropriate (like real exams)
   - Use proper Indian terminology: Lok Sabha, Rajya Sabha, Panchayat, not "lower house"
   - Currency always in ₹ (rupees)

5. EXPLANATION QUALITY:
   - Each explanation must say WHY the correct answer is right
   - AND briefly why the most tempting wrong option is incorrect
   - Maximum 2 sentences

OUTPUT: Return ONLY this JSON, nothing else — no markdown, no code blocks, no text before or after:
{
  "questions": [
    {
      "question": "Question text ending with ?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctIndex": 0,
      "explanation": "Correct answer explanation. Why wrong options are wrong."
    }
  ]
}

correctIndex = position (0-3) of the correct option in the array.
Generate exactly ${count} questions now. Start immediately with the JSON:`;
}

// ── Daily Quiz Generator ───────────────────────────────────────
// Called once per day per user session. Checks Firestore cache
// (dailyQuiz/{YYYY-MM-DD}) first. If today's questions exist,
// returns them immediately (no Groq call). If not, calls Groq to
// generate 15 fresh current affairs questions, saves to Firestore
// cache, and returns. This means Groq is called at most ONCE per day
// total for all users — extremely cost efficient (~₹0.25/day).
exports.generateDailyQuiz = onCall(
    {
      secrets: [GROQ_API_KEY],
      timeoutSeconds: 60,
      maxInstances: 10,
    },
    async (request) => {
      // Auth check
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Must be signed in.");
      }

      // Get today's date as IST (India Standard Time)
      const now = new Date();
      const istOffset = 5.5 * 60 * 60 * 1000; // IST = UTC+5:30
      const istDate = new Date(now.getTime() + istOffset);
      const today = istDate.toISOString().split("T")[0]; // YYYY-MM-DD

      // Check Firestore cache first
      const cacheRef = db.collection("dailyQuiz").doc(today);
      const cached = await cacheRef.get();

      if (cached.exists) {
        const data = cached.data();
        logger.info(`Daily quiz cache hit for ${today}.`);
        return {
          questions: data.questions,
          date: today,
          source: "cache",
        };
      }

      // Not cached — generate with Groq
      logger.info(`Generating fresh daily quiz for ${today}.`);

      // Fetch the last 10 days of quizzes so we can tell the model
      // what's already been asked and steer it away from repeating
      // the same "safe, well-known" facts every day.
      const recentQuestions = await getRecentQuizQuestions(istDate, 10);

      const prompt = buildDailyQuizPrompt(today, recentQuestions);
      let questions = null;
      let lastError = null;

      for (let attempt = 1; attempt <= 3; attempt++) {
        try {
          const raw = await callGroq(GROQ_API_KEY.value(), prompt);
          const parsed = extractAndParseJSON(raw);
          const validated = validateDailyQuizQuestions(parsed);
          if (validated) {
            questions = validated;
            logger.info(`Daily quiz generated on attempt ${attempt}.`);
            break;
          }
          logger.warn(`Attempt ${attempt}: invalid daily quiz. Retrying.`);
        } catch (err) {
          lastError = err;
          logger.warn(`Daily quiz attempt ${attempt} failed: ${err.message}`);
          if (attempt < 3) await sleep(2000 * attempt);
        }
      }

      if (!questions) {
        throw new HttpsError("internal",
            "Could not generate daily quiz. Please try again.");
      }

      // Shuffle each question's options so the correct answer isn't
      // predictably in position A — LLMs are biased toward putting
      // it first, this guarantees a genuinely random distribution.
      questions = shuffleAllQuestions(questions, "correct");

      // Save to Firestore cache — expires after 2 days
      const expiresAt = new Date(istDate);
      expiresAt.setDate(expiresAt.getDate() + 2);

      await cacheRef.set({
        questions,
        date: today,
        generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      });

      logger.info(`Daily quiz for ${today} cached in Firestore.`);

      return {
        questions,
        date: today,
        source: "groq",
      };
    },
);

// ── Fetch recent daily quiz questions for dedup ──────────────────
// Pulls question text from the last N days of dailyQuiz docs, so
// the prompt can explicitly tell the model to avoid repeating them.
async function getRecentQuizQuestions(istDate, daysBack) {
  const questionTexts = [];
  try {
    for (let i = 1; i <= daysBack; i++) {
      const pastDate = new Date(istDate);
      pastDate.setDate(pastDate.getDate() - i);
      const dateStr = pastDate.toISOString().split("T")[0];

      const doc = await db.collection("dailyQuiz").doc(dateStr).get();
      if (doc.exists) {
        const qs = doc.data().questions || [];
        qs.forEach((q) => questionTexts.push(q.question));
      }
    }
  } catch (err) {
    logger.warn(`Could not fetch recent quiz questions: ${err.message}`);
    // Non-fatal — just proceed without the avoid-list if this fails
  }
  return questionTexts;
}

// ── Daily Quiz Prompt ─────────────────────────────────────────
function buildDailyQuizPrompt(dateStr, recentQuestions) {
  // Parse date for context
  const date = new Date(dateStr);
  const months = ["January","February","March","April","May","June",
    "July","August","September","October","November","December"];
  const formattedDate =
    `${date.getDate()} ${months[date.getMonth()]} ${date.getFullYear()}`;

  return `You are India's most experienced current affairs expert who has been setting daily quiz questions for SSC CGL, IBPS PO, RRB NTPC, Punjab Police, and UPSC aspirants for 15 years.

Today's date: ${formattedDate}
Task: Generate exactly 15 multiple-choice current affairs questions for today's daily quiz.

TOPIC DISTRIBUTION (follow this mix for 15 questions):
- 4 questions: National affairs (Indian government, politics, economy, schemes, appointments)
- 3 questions: International affairs (world events, India's foreign relations, summits, treaties)
- 3 questions: Sports (recent tournaments, India's performance, awards)
- 2 questions: Science & Technology (ISRO, new discoveries, tech developments in India)
- 2 questions: Awards & Recognition (Padma, Nobel, national honours, sporting awards)
- 1 question: Economy & Finance (RBI decisions, GDP, budget, banking sector news)

FOCUS ON (in order of priority):
1. Events from the last 3-6 months that are likely to appear in upcoming exams
2. India-specific or India-relevant events
3. Punjab and North India specific developments (important for your primary audience)
4. Global events that affect India or that Indian exam setters commonly test

${recentQuestions && recentQuestions.length > 0 ? `
AVOID REPEATING THESE RECENTLY-ASKED QUESTIONS/TOPICS (last 10 days):
${recentQuestions.map((q, i) => `${i + 1}. ${q}`).join("\n")}

Generate genuinely DIFFERENT questions covering different events,
people, or facts than the above list. Do not just reword these.
` : ""}

QUESTION QUALITY RULES:
1. All 4 options must be from the SAME CATEGORY — no obviously wrong options
   BAD: "Which country hosted G20?" Options: India, USA, China, The Moon [Moon is absurd]
   GOOD: "Which country hosted G20 2023?" Options: India, Indonesia, Japan, South Africa [all G20 members]

2. Questions must test SPECIFIC knowledge, not vague awareness
   BAD: "What happened in India in 2025?" [too vague]
   GOOD: "Who was appointed as the new RBI Governor in December 2024?" [specific and testable]

3. Only include facts you are CERTAIN about — no guessing on specific dates/numbers
   If unsure of exact figures, ask about the concept/category instead

4. Explanation must be 1-2 sentences: why correct, and one key related fact

5. Category field should be one of: National Affairs, International Affairs, Sports, Science & Technology, Awards & Recognition, Economy & Finance

Return ONLY this JSON — no markdown, no code blocks, no text before or after:
{
  "questions": [
    {
      "question": "Question text ending with ?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correct": 0,
      "category": "National Affairs",
      "explanation": "Explanation of correct answer and one related fact."
    }
  ]
}

correct = index (0-3) of the correct option in the array.
Generate all 15 questions now:`;
}

// ── Validate daily quiz questions ────────────────────────────
function validateDailyQuizQuestions(parsed) {
  if (!parsed || !Array.isArray(parsed.questions)) return null;
  const qs = parsed.questions;

  const valid = qs.filter((q) => {
    if (typeof q.question !== "string" || q.question.trim().length < 10) {
      return false;
    }
    if (!Array.isArray(q.options) || q.options.length !== 4) return false;
    if (typeof q.correct !== "number" ||
        q.correct < 0 || q.correct > 3) return false;
    if (q.options.some((o) =>
      typeof o !== "string" || o.trim().length === 0)) return false;
    return true;
  });

  // Need at least 8 valid questions
  if (valid.length < 12) return null;
  return valid.slice(0, 15);
}

// ── Call Groq API ─────────────────────────────────────────────
async function callGroq(apiKey, prompt) {
  const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model: "llama-3.3-70b-versatile",
      messages: [
        {
          role: "system",
          content: "You are an expert Indian government exam question setter. You always respond with valid JSON only — no markdown, no code blocks, no explanation text. Just the raw JSON object.",
        },
        {
          role: "user",
          content: prompt,
        },
      ],
      temperature: 0.6,
      max_tokens: 4096,
      // Force JSON response — Groq supports this via response_format
      response_format: {type: "json_object"},
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Groq API error ${response.status}: ${errorBody}`);
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content;

  if (!content) throw new Error("Groq returned empty response.");

  return content;
}

// ── Extract and parse JSON robustly ──────────────────────────
// Handles cases where model wraps JSON in markdown code fences
// or adds text before/after the JSON object
function extractAndParseJSON(raw) {
  let text = raw.trim();

  // Strip markdown code fences if present
  text = text.replace(/^```json\s*/i, "").replace(/```\s*$/i, "");
  text = text.replace(/^```\s*/i, "").replace(/```\s*$/i, "");

  // Try direct parse first
  try {
    return JSON.parse(text);
  } catch (_) {
    // Try to extract JSON object using regex
    const match = text.match(/\{[\s\S]*\}/);
    if (match) {
      try {
        return JSON.parse(match[0]);
      } catch (e) {
        throw new Error(`JSON parse failed: ${e.message}`);
      }
    }
    throw new Error("No valid JSON object found in response.");
  }
}

// ── Validate question set ─────────────────────────────────────
function validateQuestions(parsed, expectedCount) {
  if (!parsed || !Array.isArray(parsed.questions)) return null;
  const qs = parsed.questions;
  if (qs.length === 0) return null;

  const valid = qs.filter((q) => {
    if (typeof q.question !== "string" || q.question.trim().length < 10) {
      return false;
    }
    if (!Array.isArray(q.options) || q.options.length !== 4) return false;
    if (typeof q.correctIndex !== "number" ||
        q.correctIndex < 0 || q.correctIndex > 3) return false;
    if (q.options.some((o) =>
      typeof o !== "string" || o.trim().length === 0)) return false;
    return true;
  });

  // Accept if we got at least 80% of requested count
  if (valid.length < Math.ceil(expectedCount * 0.8)) return null;

  // Trim to exact count if we got more
  return valid.slice(0, expectedCount);
}

// ── Fallback question bank ────────────────────────────────────
async function getFallbackQuestions(topic, count) {
  try {
    const normalized = topic.toLowerCase().replace(/[^a-z0-9]/g, "_");
    let snap = await db.collection("battleFallbackQuestions")
        .doc(normalized).get();
    if (!snap.exists) {
      snap = await db.collection("battleFallbackQuestions")
          .doc("general").get();
    }
    if (!snap.exists) return null;
    const all = snap.data().questions || [];
    if (all.length === 0) return null;
    const shuffled = all.sort(() => Math.random() - 0.5);
    return shuffled.slice(0, Math.min(count, shuffled.length));
  } catch (err) {
    logger.error("Fallback fetch failed:", err);
    return null;
  }
}

// ── Shuffle a question's options so the correct answer isn't
//    predictably in the same position every time ─────────────────
//
// LLMs have a well-documented bias toward placing the correct MCQ
// answer in the first position when asked to generate both the
// question and its own answer key. Rather than trying to prompt our
// way out of this (unreliable), we shuffle deterministically in code
// after generation — this guarantees a genuinely random distribution
// regardless of what the model does.
//
// `indexField` is the name of the field holding the correct answer's
// position — battle questions use "correctIndex", daily quiz
// questions use "correct". Same shuffle logic, different field name.
function shuffleQuestionOptions(question, indexField) {
  const correctAnswerText = question.options[question[indexField]];

  // Fisher-Yates shuffle
  const shuffled = [...question.options];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }

  const newCorrectIndex = shuffled.indexOf(correctAnswerText);

  return {
    ...question,
    options: shuffled,
    [indexField]: newCorrectIndex,
  };
}

// Applies shuffleQuestionOptions to every question in an array.
function shuffleAllQuestions(questions, indexField) {
  return questions.map((q) => shuffleQuestionOptions(q, indexField));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}