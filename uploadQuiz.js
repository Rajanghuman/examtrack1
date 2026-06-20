const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const quizQuestions = [
  {
    question: "Who is the current Prime Minister of India?",
    options: ["Narendra Modi", "Rahul Gandhi", "Amit Shah", "Rajnath Singh"],
    correct: 0,
    explanation: "Narendra Modi has been serving as the Prime Minister of India since May 2014.",
    category: "National"
  },
  {
    question: "Which article of the Indian Constitution deals with the Right to Equality?",
    options: ["Article 14-18", "Article 19-22", "Article 23-24", "Article 25-28"],
    correct: 0,
    explanation: "Articles 14 to 18 of the Indian Constitution deal with the Right to Equality.",
    category: "GK"
  },
  {
    question: "How many seats are there in the Lok Sabha?",
    options: ["543", "545", "552", "550"],
    correct: 0,
    explanation: "The Lok Sabha has 543 elected seats.",
    category: "National"
  },
  {
    question: "Who was the first President of India?",
    options: ["Dr. Rajendra Prasad", "Dr. S. Radhakrishnan", "V.V. Giri", "Zakir Husain"],
    correct: 0,
    explanation: "Dr. Rajendra Prasad was the first President of India (1950–1962).",
    category: "History"
  },
  {
    question: "Which state has the largest area in India?",
    options: ["Rajasthan", "Madhya Pradesh", "Maharashtra", "Uttar Pradesh"],
    correct: 0,
    explanation: "Rajasthan is the largest state in India by area, covering about 342,239 sq km.",
    category: "Geography"
  },
  {
    question: "What is the full form of GDP?",
    options: ["Gross Domestic Product", "General Domestic Production", "Gross Development Product", "General Development Program"],
    correct: 0,
    explanation: "GDP stands for Gross Domestic Product — total monetary value of all goods and services produced in a country.",
    category: "Economy"
  },
  {
    question: "Which organization releases the Human Development Index (HDI)?",
    options: ["UNDP", "World Bank", "IMF", "WHO"],
    correct: 0,
    explanation: "The United Nations Development Programme (UNDP) releases the Human Development Index annually.",
    category: "Economy"
  },
  {
    question: "Which bank is known as the 'Banker of Banks' in India?",
    options: ["Reserve Bank of India", "State Bank of India", "Bank of India", "Punjab National Bank"],
    correct: 0,
    explanation: "The Reserve Bank of India (RBI) is called the Banker of Banks.",
    category: "Banking"
  },
  {
    question: "Which planet is known as the Red Planet?",
    options: ["Mars", "Jupiter", "Saturn", "Venus"],
    correct: 0,
    explanation: "Mars is called the Red Planet because its surface is covered with iron oxide (rust).",
    category: "Science"
  },
  {
    question: "What is the chemical symbol for Gold?",
    options: ["Au", "Ag", "Fe", "Cu"],
    correct: 0,
    explanation: "The chemical symbol for Gold is Au, from the Latin word 'Aurum'.",
    category: "Science"
  },
  {
    question: "ISRO stands for?",
    options: ["Indian Space Research Organisation", "Indian Scientific Research Organisation", "Institute of Space Research Operations", "Indian Satellite Research Organisation"],
    correct: 0,
    explanation: "ISRO stands for Indian Space Research Organisation, headquartered in Bengaluru.",
    category: "Science"
  },
  {
    question: "Which country hosted the FIFA World Cup 2026?",
    options: ["USA, Canada & Mexico", "Brazil & Argentina", "Europe", "China"],
    correct: 0,
    explanation: "The FIFA World Cup 2026 was hosted jointly by the United States, Canada, and Mexico.",
    category: "Sports"
  },
  {
    question: "How many players are there in a cricket team?",
    options: ["11", "9", "12", "10"],
    correct: 0,
    explanation: "A cricket team consists of 11 players.",
    category: "Sports"
  },
  {
    question: "Sachin Tendulkar's total international runs?",
    options: ["34,357", "28,000", "30,000", "32,000"],
    correct: 0,
    explanation: "Sachin Tendulkar scored 34,357 runs in international cricket — a world record.",
    category: "Sports"
  },
  {
    question: "Which sport is associated with the term 'Love'?",
    options: ["Tennis", "Cricket", "Badminton", "Table Tennis"],
    correct: 0,
    explanation: "In Tennis, 'Love' means zero or no points scored.",
    category: "Sports"
  },
  {
    question: "Which is the longest river in India?",
    options: ["Ganga", "Godavari", "Yamuna", "Krishna"],
    correct: 0,
    explanation: "The Ganga is the longest river in India, flowing approximately 2,525 km.",
    category: "Geography"
  },
  {
    question: "Which is the highest peak in India?",
    options: ["Kangchenjunga", "Mount Everest", "K2", "Nanda Devi"],
    correct: 0,
    explanation: "Kangchenjunga (8,586 m) is the highest peak in India.",
    category: "Geography"
  },
  {
    question: "Which is the smallest state in India by area?",
    options: ["Goa", "Sikkim", "Tripura", "Manipur"],
    correct: 0,
    explanation: "Goa is the smallest state in India by area, covering about 3,702 sq km.",
    category: "Geography"
  },
  {
    question: "Which ocean is the largest in the world?",
    options: ["Pacific Ocean", "Atlantic Ocean", "Indian Ocean", "Arctic Ocean"],
    correct: 0,
    explanation: "The Pacific Ocean is the largest ocean, covering more than 30% of Earth's surface.",
    category: "Geography"
  },
  {
    question: "When did India gain independence?",
    options: ["15 August 1947", "26 January 1950", "15 August 1945", "26 January 1947"],
    correct: 0,
    explanation: "India gained independence from British rule on 15 August 1947.",
    category: "History"
  },
  {
    question: "Who is known as the Father of the Indian Constitution?",
    options: ["Dr. B.R. Ambedkar", "Mahatma Gandhi", "Jawaharlal Nehru", "Sardar Patel"],
    correct: 0,
    explanation: "Dr. B.R. Ambedkar is known as the Father of the Indian Constitution.",
    category: "History"
  },
  {
    question: "The Battle of Panipat (First) was fought in which year?",
    options: ["1526", "1556", "1761", "1576"],
    correct: 0,
    explanation: "The First Battle of Panipat was fought in 1526 between Babur and Ibrahim Lodi.",
    category: "History"
  },
  {
    question: "Who gave the slogan 'Do or Die'?",
    options: ["Mahatma Gandhi", "Bal Gangadhar Tilak", "Subhas Chandra Bose", "Bhagat Singh"],
    correct: 0,
    explanation: "Mahatma Gandhi gave the slogan 'Do or Die' during the Quit India Movement in 1942.",
    category: "History"
  },
  {
    question: "Which year was the Indian National Congress founded?",
    options: ["1885", "1905", "1920", "1857"],
    correct: 0,
    explanation: "The Indian National Congress was founded in 1885 by A.O. Hume.",
    category: "History"
  },
  {
    question: "What does CPU stand for?",
    options: ["Central Processing Unit", "Computer Processing Unit", "Core Processing Unit", "Central Program Unit"],
    correct: 0,
    explanation: "CPU stands for Central Processing Unit — primary component of a computer.",
    category: "Computer"
  },
  {
    question: "India's GDP growth rate for FY 2025-26?",
    options: ["7.7%", "6.5%", "8.2%", "5.9%"],
    correct: 0,
    explanation: "India's GDP growth rate for FY 2025-26 was approximately 7.7%.",
    category: "Current Affairs"
  },
  {
    question: "Who invented the telephone?",
    options: ["Alexander Graham Bell", "Thomas Edison", "Nikola Tesla", "Guglielmo Marconi"],
    correct: 0,
    explanation: "Alexander Graham Bell invented the telephone in 1876.",
    category: "Science"
  },
  {
    question: "Fundamental Duties were added by which amendment?",
    options: ["42nd", "40th", "44th", "46th"],
    correct: 0,
    explanation: "Fundamental Duties were added by the 42nd Constitutional Amendment in 1976.",
    category: "GK"
  },
  {
    question: "Which organelle is called 'Powerhouse of cell'?",
    options: ["Mitochondria", "Nucleus", "Ribosome", "Chloroplast"],
    correct: 0,
    explanation: "Mitochondria produce energy (ATP) through cellular respiration.",
    category: "Science"
  },
  {
    question: "National Song of India is?",
    options: ["Vande Mataram", "Jana Gana Mana", "Saare Jahan Se Accha", "Mile Sur Mera Tumhara"],
    correct: 0,
    explanation: "Vande Mataram is the National Song. Jana Gana Mana is the National Anthem.",
    category: "GK"
  },
];

async function uploadQuiz() {
  console.log(`\n📋 Uploading ${quizQuestions.length} quiz questions...\n`);
  let added = 0, updated = 0;

  for (let i = 0; i < quizQuestions.length; i++) {
    const q = quizQuestions[i];
    const docId = `q${String(i + 1).padStart(3, '0')}`;
    const docRef = db.collection('quiz').doc(docId);
    const existing = await docRef.get();

    if (!existing.exists) {
      await docRef.set(q);
      console.log(`✅ ADDED: ${docId}`);
      added++;
    } else {
      await docRef.set(q);
      console.log(`🔄 UPDATED: ${docId}`);
      updated++;
    }
  }

  console.log('\n─────────────────────────────');
  console.log(`✅ Added:   ${added}`);
  console.log(`🔄 Updated: ${updated}`);
  console.log(`📋 Total:   ${quizQuestions.length}`);
  console.log('─────────────────────────────\n');
  console.log('✅ Quiz upload complete!');
  process.exit(0);
}

uploadQuiz().catch(err => {
  console.error('❌ Error:', err);
  process.exit(1);
});
