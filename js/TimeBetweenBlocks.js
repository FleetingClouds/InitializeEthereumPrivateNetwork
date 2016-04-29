
var divisor = 0;
function ma(pv, cv, ci, theQueue) {
  idx = Number(ci);
/*
  var multiplier = idx + 1;
  var ret = pv + cv * multiplier;
  var diff = ret - pv;
  console.log(idx + " : " + pv + " : " + cv + " >> "  + ret + " ("  + diff + ")");
*/
  weight = (idx + 1) * 0.25;
  divisor += weight;
  return pv + cv * weight;
};

function movingAverage (anArray, nextVal) {
  anArray.push(nextVal);
  anArray.shift();

  divisor = 0;
  result = anArray.reduce(ma, 0) / divisor;
  console.log("[0] = " + anArray[0] + "[9] = " + anArray[9] + " Weighted avg. = " + Math.round( result ) + ".");

};

var queue=[500, 500, 500, 500, 500, 500, 500, 500, 500, 500];

/*
divisor = 1;
result = queue.reduce(ma, 0) / divisor;
console.log("Weighted avg. = " + result);
*/

var newTime = new Date().getTime();
var startTime = newTime;
var elapsed = newTime - startTime;

var oldBlockNum = 0;
function checkWork( aBlockHash ) {
  if (typeof aBlockHash == 'undefined') {

    // console.log("Nothing " + aBlockHash);
  
  } else {
  
//    console.log("Thing " + aBlockHash);
    var newBlock = eth.getBlock(aBlockHash);
    var newBlockNum = newBlock.number;
    
    if (oldBlockNum < newBlockNum) {
      oldBlockNum = newBlockNum;
      newTime = new Date().getTime();
      elapsed = newTime - startTime;
      startTime = newTime;
      
      console.log("Block #" + newBlockNum + ". Elapsed : " + elapsed);
      movingAverage (queue, elapsed);
    }
  }
}

eth.filter("latest", function(err, hashBlock) {
  checkWork(hashBlock); 
});

checkWork();
