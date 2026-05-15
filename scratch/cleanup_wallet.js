import admin from 'firebase-admin';

// Initialize with your project ID
admin.initializeApp({
  projectId: 'device-streaming-d7021871' // From the logs
});

const db = admin.firestore();
const agentId = 'uEM6sbAwKhenDXO53hXuiR6HRRD3';

async function cleanupAgentWallet() {
  console.log(`Starting cleanup for Agent: ${agentId}`);

  try {
    // 1. Reset Balance
    await db.collection('agents').doc(agentId).set({
      wallet_balance: 0,
      walletBalance: 0 // Reset both variants to be sure
    }, { merge: true });
    console.log('Wallet balance reset to 0.');

    // 2. Clear Transactions
    const txnSnap = await db.collection('agents').doc(agentId).collection('transactions').get();
    const batch = db.batch();
    
    txnSnap.docs.forEach((doc) => {
      batch.delete(doc.ref);
    });

    if (txnSnap.docs.length > 0) {
      await batch.commit();
      console.log(`Deleted ${txnSnap.docs.length} transaction records.`);
    } else {
      console.log('No transactions found to delete.');
    }

    console.log('Cleanup complete! Please refresh the app.');
  } catch (error) {
    console.error('Cleanup failed:', error);
  }
}

cleanupAgentWallet();
