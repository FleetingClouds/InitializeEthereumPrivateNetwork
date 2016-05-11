/*

    Monitor the blockchain for pending transactions.
    Do mining until no pending transactions

*/
var mining_threads = 1

function mineIfWorkToBeDone() {
  if (eth.getBlock("pending").transactions.length > 0) {
    if (eth.mining) return;
    console.log(" ~~ Pending transactions! Start mining until ...");
    miner.start(mining_threads);
  } else {
    miner.stop();
    if (eth.mining) console.log("   . . . no pending transactions. Stopped mining.");
  }
  console.log("Balance now : " + web3.fromWei(eth.getBalance(eth.accounts[0]), "ether") );
}

eth.filter("latest", function(err, block) { mineIfWorkToBeDone(); });
eth.filter("pending", function(err, block) { mineIfWorkToBeDone(); });

mineIfWorkToBeDone();
