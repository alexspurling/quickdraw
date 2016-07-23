var app = Elm.Main.fullscreen();

var buffer;
var bufferCtx;
var canvas;
var ctx;
var scale = 1;

app.ports.loadCanvas.subscribe(function() {
  canvas = document.getElementById("mycanvas");
  ctx = canvas.getContext("2d");

  buffer = document.createElement('canvas');
  buffer.width = 10000;
  buffer.height = 10000;
  bufferCtx = buffer.getContext('2d');
  bufferCtx.lineWidth = 10;
  bufferCtx.lineCap = 'round';

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
      storeToBuffer();
  }, false);

  canvas.addEventListener("wheel", function (e) {
      app.ports.canvasZoom.send(e.deltaY);
      zoomCanvas(canvas, e);
  }, false);
});

function resizeCanvas(canvas) {
  //Get the position of the containing div
  var canvasTop = canvas.offsetParent.offsetTop;
  var canvasLeft = canvas.offsetParent.offsetLeft;
  // resize & clear the original canvas and copy back in pixel data from the buffer //
  canvas.width = window.innerWidth - canvasLeft;
  canvas.height = window.innerHeight - canvasTop;
  ctx.lineWidth = 10;
  ctx.lineCap = 'round';
  ctx.drawImage(buffer, 0, 0);
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

function storeToBuffer() {
  bufferCtx.drawImage(canvas, 0, 0);
}

function zoomCanvas(canvas, e) {
  var scaleFactor = Math.pow(2,(e.deltaY / 1000));
  scale = scale * scaleFactor;
  console.log("Scale factor", scale);

  //Find the new top and left of the scaled image
  var scaledWidth = (canvas.width * scale);
  var scaledHeight = (canvas.height * scale);
  var diffX = canvas.width - scaledWidth;
  var diffY = canvas.height - scaledHeight;
  var newLeft = diffX / 2;
  var newTop = diffY / 2;

  ctx.clearRect(0, 0, canvas.width, canvas.height);
  ctx.drawImage(buffer, newLeft, newTop, scaledWidth, scaledHeight, 0, 0, canvas.width, canvas.height);
}