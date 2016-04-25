/*

   Monitor the blockchain for pending transactions.
   Do mining until no pending transactions

*/
var mining_threads = 1

function mineIfWorkToBeDone() {
    if (eth.getBlock("pending").transactions.length > 0) {
        if (eth.mining) return;
        console.log("  * ==  Pending transactions! Mining...  == *");
        miner.start(mining_threads);
    } else {
        miner.stop();  // This param means nothing
        console.log("  * ==  No transactions! Mining stopped.  == *");
    }
}

eth.filter("latest", function(err, block) { mineIfWorkToBeDone(); });
eth.filter("pending", function(err, block) { mineIfWorkToBeDone(); });

mineIfWorkToBeDone();
