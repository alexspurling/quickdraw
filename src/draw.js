var app = Elm.Main.fullscreen();

var canvas;
var ctx;

app.ports.loadCanvas.subscribe(function() {
  canvas = document.getElementById("mycanvas");

  resizeCanvas(canvas);
  //Resize on window resize
  window.onresize = function() {
    resizeCanvas(canvas);
  };

  ctx = canvas.getContext("2d");

  ctx.lineWidth = 10;
  ctx.lineCap = 'round';
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
      console.log("Mouse down", e);
      app.ports.canvasMouseDown.send({});
  }, false);

  canvas.addEventListener("mouseup", function (e) {
      console.log("Mouse up", e);
      app.ports.canvasMouseUp.send({});
  }, false);
});

function resizeCanvas(canvas) {
  //Get the position of the containing div
  var canvasTop = canvas.offsetParent.offsetTop;
  var canvasLeft = canvas.offsetParent.offsetLeft;
  canvas.width = window.innerWidth - canvasLeft - 10;
  canvas.height = window.innerHeight - canvasTop - 10;
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