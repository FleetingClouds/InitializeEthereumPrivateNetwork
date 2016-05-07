loadScript("/home/you/.ssh/pwdPrimary.js");

var primary = eth.accounts[0];
personal.unlockAccount(primary, pwdPrimary());

console.log("Paying . . . ");
eth.sendTransaction(
  {
    from : primary,
    to : "0xc3cb526c6cbb072ea1913d5ba98e2670b3cb0d44",
    value : web3.toWei(1, "ether")
  }, function (e) {  console.log("Paid"); }
);

/*  --- */

