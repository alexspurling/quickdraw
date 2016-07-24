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
      app.ports.canvasMouseDown.send({});
  }, false);

  canvas.addEventListener("mouseup", function (e) {
      app.ports.canvasMouseUp.send({});
      storeToTileMap();
  }, false);

  canvas.addEventListener("wheel", function (e) {
      app.ports.canvasZoom.send(e.deltaY);
      zoomCanvas(canvas, e);
  }, false);

  document.addEventListener("keydown", function (e) {
      if ("ArrowRight" == e.key) {
        pan(1,0);
      } else if ("ArrowLeft" == e.key) {
        pan(-1,0);
      } else if ("ArrowUp" == e.key) {
        pan(0,-1);
      } else if ("ArrowDown" == e.key) {
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
  copyFromTileMap(ctx);
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
  tileCtx.strokeRect(0,0,tileSize,tileSize);
  return tileCtx;
}

function copyFromTileMap(ctx) {
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  visibleTiles(function(i, j) {
    var tile = tileMap[i][j];
    //The position on the canvas on which to place the tiles
    var canvasX = i * tileSize - curX;
    var canvasY = j * tileSize - curY;
    ctx.drawImage(tile.canvas, canvasX, canvasY);
  });
}

function getMousePos(canvas, touchEvent) {
  var rect = canvas.getBoundingClientRect();
  var canvasX = parseInt(touchEvent.touches[0].clientX - rect.left);
  var canvasY = parseInt(touchEvent.touches[0].clientY - rect.top);
  return {x: canvasX, y: canvasY};
}

app.ports.drawLine.subscribe(function(line) {
  ctx.beginPath();
  ctx.strokeStyle = line.colour;
  ctx.moveTo(line.from.x, line.from.y);
  ctx.lineTo(line.to.x, line.to.y);
  ctx.stroke();
  ctx.closePath();
});

function storeToTileMap() {
  visibleTiles(function(i, j) {
    tile = tileMap[i][j];
    //The position on the canvas from which we want to make a tile
    var canvasX = i * tileSize - curX;
    var canvasY = j * tileSize - curX;
    tile.drawImage(canvas, canvasX, canvasY, tileSize, tileSize, 0, 0, tileSize, tileSize);
  });
}

function pan(x, y) {
  curX += 10 * x;
  curY += 10 * y;
  copyFromTileMap(ctx);
}

function visibleTiles(func) {
  var tileLeft = parseInt(curX / tileSize);
  var tileTop = parseInt(curY / tileSize);
  var numTilesI = canvas.width / tileSize + 1;
  var numTilesJ = canvas.height / tileSize + 1;
  for (var i = tileLeft; i < numTilesI; i++) {
    for (var j = tileLeft; j < numTilesJ; j++) {
      func(i, j);
    }
  }
}

function zoomCanvas(canvas, e) {
//  var scaleFactor = Math.pow(2,(e.deltaY / 1000));
//  scale = scale * scaleFactor;
//  console.log("Scale factor", scale);
//
//  //Find the new top and left of the scaled image
//  var scaledWidth = (canvas.width * scale);
//  var scaledHeight = (canvas.height * scale);
//  var diffX = canvas.width - scaledWidth;
//  var diffY = canvas.height - scaledHeight;
//  var newLeft = diffX / 2;
//  var newTop = diffY / 2;
//
//  ctx.clearRect(0, 0, canvas.width, canvas.height);
//  ctx.drawImage(buffer, newLeft, newTop, scaledWidth, scaledHeight, 0, 0, canvas.width, canvas.height);
}