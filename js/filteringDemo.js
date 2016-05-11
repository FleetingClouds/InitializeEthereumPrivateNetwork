console.log("        == Filtering Demo == ");

if (typeof myFilter != "undefined") {
  myLastFilter.stopWatching();
  myLastFilter = null;

  myNextFilter.stopWatching();
  myNextFilter = null;
}

function mineIfTransaction (error, hashBlock) {
  console.log(
       "Pending block transactions : " + web3.eth.getBlockTransactionCount('pending') 
    + ". Latest block transactions : " + web3.eth.getBlockTransactionCount('latest') + ".");
  if ( error) {
    console.log("Filter error = " + error);
  } else {
    count = web3.eth.getBlockTransactionCount(hashBlock);
    if ( count > 0 ) {
      blk = web3.eth.getBlock(hashBlock);
      console.log("Block number : " + blk.number + " has " + count + " transactions.");
      var transactions = web3.eth.getBlock(hashBlock).transactions
      transactions.forEach(function(hashTransaction) {
        transaction = web3.eth.getTransaction(hashTransaction);
        console.log(
             "Payment of '" + web3.fromWei(transaction.value, "ether")
          + "' Eth, from '" + transaction.from 
                 + "' to '" + transaction.to + "'."
        );
      });

    }
    // console.log("Done");
  }
};

function mineIfLatestTransaction (error, hashBlock) {
  console.log(" ~~ Latest = " + hashBlock);
  mineIfTransaction (error, hashBlock);
};

function mineIfPendingTransaction (error, hashBlock) {
  console.log("  ***** PENDING = " + hashBlock);
  mineIfTransaction (error, hashBlock);
};


var optLatest='latest';
var myLastFilter = web3.eth.filter(optLatest, mineIfLatestTransaction);

var optNext='pending';
var myNextFilter = web3.eth.filter(optNext, mineIfPendingTransaction);

