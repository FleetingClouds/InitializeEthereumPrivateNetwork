loadScript("/home/you/.ssh/pwdPrimary.js");

var primary = eth.accounts[0];
personal.unlockAccount(primary, pwdPrimary());

var amount = 1.51;
var payee = ROOT_PRIMARY_ACCOUNT;
console.log("Paying " + amount + " out of " + web3.fromWei(eth.getBalance(eth.accounts[0]), "ether") + " from account : " + primary);
eth.sendTransaction(
  {
    from : primary,
    to : payee,
    value : web3.toWei(amount, "ether")
  }, function (e) {  console.log("Paid to " + payee); }
);

/*  --- */

