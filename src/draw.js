var app = Elm.Main.fullscreen();

var canvas;
var ctx;
var scale = 1;

//Store a map of maps of canvas buffers
var tileMap;
var tileSize = 400;
//Current x,y position on the world
var curX = 0;
var curY = 0;
//Current zoom
var zoom = 0;
var scale = 1;

app.ports.loadCanvas.subscribe(function() {
  canvas = document.getElementById("mycanvas");
  ctx = canvas.getContext("2d");

  tileMap = {};

  resizeCanvas(canvas);
  //Resize on window resize
  window.onresize = function() {
    resizeCanvas(canvas);
  };
  console.log("Loading canvas", canvas);

  canvas.addEventListener("mousemove", function (e) {
      var canvasX = e.offsetX;
      var canvasY = e.offsetY;
      var mousePos = {x: canvasX, y: canvasY};
      var mouseDown = e.buttons == 1;
      app.ports.canvasMouseMoved.send({mousePos: mousePos, mouseDown: mouseDown});
      //Might need this to prevent dragging on mobile
//      e.preventDefault();
  }, false);

  canvas.addEventListener("touchstart", function (e) {
      //Toggle the mouse down state to off because we want to
      //set this current position as the starting
      //point for our line when we start the 'move' event
      app.ports.canvasMouseMoved.send({mousePos: getMousePos(canvas, e), mouseDown: false});
  }, false);

  canvas.addEventListener("touchmove", function (e) {
      app.ports.canvasMouseMoved.send({mousePos: getMousePos(canvas, e), mouseDown: true});
      //Might need this to prevent dragging on mobile
//      e.preventDefault();
  }, false);

  canvas.addEventListener("mousedown", function (e) {
  }, false);

  canvas.addEventListener("mouseup", function (e) {
  }, false);

  canvas.addEventListener("wheel", function (e) {
      var delta = e.deltaY;
      //Firefox gives a delta value in number of lines rather than pixels
      //so unfortunately the scrolling is lower resolution and we must scale
      //it by 20 (px per line)
      if (e.deltaMode == 1) {
          delta *= 20;
      }
      zoomCanvas(delta);
      app.ports.canvasZoom.send(zoom);
  }, false);

  document.addEventListener("keydown", function (e) {
      if (39 == e.keyCode) {
        pan(1,0);
      } else if (37 == e.keyCode) {
        pan(-1,0);
      } else if (38 == e.keyCode) {
        pan(0,-1);
      } else if (40 == e.keyCode) {
        pan(0,1);
      }
  }, false);
});

function resizeCanvas(canvas) {

  //Initialise new buffer canvases if necessary
  var canvasWidth = window.innerWidth;
  var canvasHeight = window.innerHeight;

  console.log("Resizing to " + canvasWidth + ", " + canvasHeight);

  // resize & clear the original canvas and copy back in pixel data from the buffer //
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;

  createTiles();

  //Reset the drawing properties
  ctx.lineWidth = 10;
  ctx.lineCap = 'round';

  //Copy the tile map to the canvas
  copyFromTileMap();
}

function createTiles() {
  visibleTiles(function(i, j) {
    //If the tile doesn't exist yet, create it
    var tileCol = tileMap[i];
    if (!tileCol) {
      tileMap[i] = tileCol = {};
    }
    var tile = tileCol[j];
    if (!tile) {
      tileCol[j] = tile = newTile(i, j);
    }
  });
}

function newTile(i, j) {
  console.log("Creating tile " + i + ", " + j);
  var tile = document.createElement('canvas');
  tile.width = tileSize;
  tile.height = tileSize;
  var tileCtx = tile.getContext('2d');
  tileCtx.lineWidth = 4;
  tileCtx.lineCap = 'round';
//  tileCtx.strokeRect(0,0,tileSize,tileSize);
  return tileCtx;
}

function copyFromTileMap() {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  visibleTiles(function(i, j) {
    var tile = tileMap[i][j];
    //The position on the canvas on which to place the tiles
    var canvasX = i * (tileSize / scale) - (curX / scale);
    var canvasY = j * (tileSize / scale) - (curY / scale);
    var canvasTileSize = tileSize / scale;
    ctx.drawImage(tile.canvas, canvasX, canvasY, canvasTileSize, canvasTileSize);
  });
}

function getMousePos(canvas, touchEvent) {
  var rect = canvas.getBoundingClientRect();
  var canvasX = parseInt(touchEvent.touches[0].clientX - rect.left);
  var canvasY = parseInt(touchEvent.touches[0].clientY - rect.top);
  return {x: canvasX, y: canvasY};
}

app.ports.drawLine.subscribe(function(line) {
  var tileStart = tileAt(line.from.x, line.from.y);
  var tileEnd = tileAt(line.to.x, line.to.y);

  //Loop through all the tiles that this line might pass through and draw on them
  //Note that the line might not actually intersect all of the tiles in which
  //case the line drawn will simply not be visible

  var allTiles = [];
  for (var i = tileStart.i; i <= tileEnd.i; i++) {
    for (var j = tileStart.j; j <= tileEnd.j; j++) {
       allTiles.push([i, j]);
       drawLineOnTile(i, j, line.from, line.to, line.colour);
    }
  }

  debug("Tiles drawn on: " + allTiles);

  copyFromTileMap();
});

function drawLineOnTile(i, j, lineFrom, lineTo, colour) {
  var tile = tileMap[i][j];

  var tileLineFromX = lineFrom.x - (i * tileSize / scale) - (curX / scale);
  var tileLineFromY = lineFrom.y - (j * tileSize / scale) - (curY / scale);

  var tileLineToX = lineTo.x - (i * tileSize / scale) - (curX / scale);
  var tileLineToY = lineTo.y - (j * tileSize / scale) - (curY / scale);

  tile.beginPath();
  tile.strokeStyle = colour;
  tile.moveTo(tileLineFromX, tileLineFromY);
  tile.lineTo(tileLineToX, tileLineToY);
  tile.stroke();
  tile.closePath();
}

function vec(x, y) {
  return {x:x, y:y};
}

//Actually the magnitude of 3D cross product
function cross(v, w) {
  return v.x * w.y - v.y * w.x;
}

function minus(v, w) {
  return {x:(v.x - w.x), y:(v.y - w.y)};
}

function plus(v, w) {
  return {x:(v.x + w.x), y:(v.y + w.y)};
}

function div(v, d) {
  return {x:(v.x / d), y:(v.y / d)};
}

function tileAt(x, y) {
  return {i: parseInt(x / tileSize),
  j: parseInt(y / tileSize)};
}

//app.ports.drawLine.subscribe(function(line) {
//  ctx.beginPath();
//  ctx.strokeStyle = line.colour;
//  ctx.moveTo(line.from.x, line.from.y);
//  ctx.lineTo(line.to.x, line.to.y);
//  ctx.stroke();
//  ctx.closePath();
//});

function storeToTileMap() {
  visibleTiles(function(i, j) {
    tile = tileMap[i][j];
    //The position on the canvas from which we want to make a tile
    var scaledTile = (tileSize / scale);
    var canvasX = i * scaledTile - (curX / scale);
    var canvasY = j * scaledTile - (curY / scale);
    tile.drawImage(canvas, canvasX, canvasY, scaledTile, scaledTile, 0, 0, tileSize, tileSize);
  });
}

function pan(x, y) {
  curX += 10 * x;
  curY += 10 * y;
  createTiles();
  copyFromTileMap();
}

function visibleTiles(func) {
  var tileLeft = parseInt(curX / tileSize) - 1;
  var tileTop = parseInt(curY / tileSize) - 1;
  var numTilesI = scale * canvas.width / tileSize + 2;
  var numTilesJ = scale * canvas.height / tileSize + 2;
  for (var i = tileLeft; i < tileLeft + numTilesI; i++) {
    for (var j = tileTop; j < tileTop + numTilesJ; j++) {
      func(i, j);
    }
  }
}

function zoomCanvas(deltaY) {
  zoom += deltaY;
  zoom = Math.min(zoom, 3000);
  zoom = Math.max(zoom, -1000);
  scale = Math.pow(2,(zoom / 1000));

  createTiles();
  copyFromTileMap();
}

function debug(debugStr) {
  document.getElementById("debug").innerHTML = debugStr;
  document.getElementById("debug").innerText = debugStr;
}