primary = eth.accounts[0];
balance = web3.fromWei(eth.getBalance(primary), "ether");

miner.setEtherbase(primary)

console.log(" =- Starting mining.");
miner.start(8); admin.sleepBlocks(3); miner.stop()  ;
console.log(" =-  Mined 3 blocks ");

balance = web3.fromWei(eth.getBalance(primary), "ether");
console.log("( Account " + primary + " holds " + balance + " Eth. )");
