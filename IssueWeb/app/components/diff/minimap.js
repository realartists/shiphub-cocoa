import h from 'hyperscript'

class Region {
  constructor(node /* DOM node */, color /* string, e.g. red or #F00 */) {
    this.node = node;
    this.color = color;
  }
}

class MiniMap {
  constructor(container, scrollable, width) {
    var style = {
      position: 'fixed',
      right: '0',
      top: '0',
      width: width + 'px',
      height: '100%',
      padding: '0',
      margin: '0',
      'background-color': this.backgroundColor()
    };
    this.regions = [];
    this.canvas = h('canvas', {style:style});
    this.scrollable = scrollable;
    container.appendChild(this.canvas);
    
    var needsDisplay = this.setNeedsDisplay.bind(this);
    
    window.addEventListener('scroll', needsDisplay);
    window.addEventListener('resize', needsDisplay);
    
    this.canvas.addEventListener('mousedown', (e) => this.mouseDown(e));
    this.canvas.addEventListener('wheel', (e) => this.mouseWheel(e));
    document.addEventListener('mousemove', (e) => this.mouseMove(e));
    document.addEventListener('mouseup', (e) => this.mouseUp(e));
  }
  
  scrollToEvent(e) {
    var myHeight = this.canvas.clientHeight;
    var scrollableHeight = this.scrollable.scrollHeight;
    var visibleHeight = myHeight;
    
    var y = e.clientY;
    
    var scrollTop = Math.floor(y * (scrollableHeight/myHeight)) - (visibleHeight * 0.5);
    scrollTop = Math.max(0, scrollTop);
    scrollTop = Math.min(scrollableHeight - visibleHeight, scrollTop);
    
    window.scroll(0, scrollTop);
  }
  
  mouseDown(e) {
    this.scrollToEvent(e);
    this._mouseDown = true;
  }
  
  mouseMove(e) {
    if (this._mouseDown) {
      this.scrollToEvent(e);
    }
  }
  
  mouseUp(e) {
    this._mouseDown = false;
  }
  
  mouseWheel(e) {
    if (this._mouseDown) return;
    
    var myHeight = this.canvas.clientHeight;
    var scrollableHeight = this.scrollable.scrollHeight;
    var visibleHeight = this.scrollable.parentNode.clientHeight;
    
    var scrollTop = this.scrollable.scrollTop;
    scrollTop += e.deltaY;
    
    scrollTop = Math.floor(scrollTop);
    scrollTop = Math.max(0, scrollTop);
    scrollTop = Math.min(scrollableHeight - visibleHeight, scrollTop);
    
    this.scrollable.scrollTop = scrollTop;
  }
  
  setNeedsDisplay() {
    if (this.needsDisplay) return;
    this.needsDisplay = true;
    window.requestAnimationFrame(() => {
      this.needsDisplay = false;
      this.draw();
    });
  }
  
  setRegions(regions /* array of Region objects */) {
    this.regions = regions || [];
    this.setNeedsDisplay();
  }
  
  backgroundColor() {
    return "#DEDEDE";
  }
  
  visibleRegionColor() {
    return "rgba(0, 0, 0, 0.2)";
  }
  
  draw() {
    var canvasWidth = this.canvas.width;
    var canvasHeight = this.canvas.height;
    
    var actualWidth = this.canvas.clientWidth;
    var actualHeight = this.canvas.clientHeight;
    
    if (actualWidth != canvasWidth) {
      this.canvas.width = actualWidth;
      canvasWidth = actualWidth;
    }
    if (actualHeight != canvasHeight) {
      this.canvas.height = actualHeight;
      canvasHeight = actualHeight;
    }
        
    var ctx = this.canvas.getContext("2d");
    var scrollableWidth = this.scrollable.scrollWidth;
    var scrollableHeight = this.scrollable.scrollHeight;
    
    var visibleHeight = canvasHeight;
    var visibleOffsetY = window.scrollY;
    
    var scaleX = canvasWidth/scrollableWidth;
    var scaleY = canvasHeight/scrollableHeight;
        
    // fill the context with the background color
    ctx.fillStyle = this.backgroundColor();
    ctx.clearRect(0, 0, canvasWidth, canvasHeight);
    ctx.fillRect(0, 0, canvasWidth, canvasHeight);
    
    // draw all of the regions
    this.regions.forEach((r, i) => {
      // compute the position of r.node within scrollable
      var offsetY = 0;
      var offsetX = 0;
      var width = r.node.clientWidth;
      var height = r.node.clientHeight;
      var n = r.node;
      while (n && n != this.scrollable) {
        offsetX += n.offsetLeft;
        offsetY += n.offsetTop;
        n = n.offsetParent;
      }
      
      ctx.fillStyle = r.color;
      
      var x = Math.floor(offsetX * scaleX);
      var y = Math.floor(offsetY * scaleY);
      var w = Math.ceil(width * scaleX);
      var h = Math.ceil(height * scaleY); 
      
      ctx.fillRect(x, y, w, h);
    });
    
    // draw the visible region
    ctx.fillStyle = this.visibleRegionColor();
    var x = 0;
    var y = Math.floor(visibleOffsetY * scaleY);
    var w = canvasWidth;
    var h = Math.ceil(visibleHeight * scaleY);
    
    var minHeight = 10.0;
    if (h < minHeight) {
      y -= Math.round((minHeight - h) / 2.0);
      h = minHeight;
    }
    
    y = Math.max(0, y);
    y = Math.min(canvasHeight - h, y);

    ctx.fillRect(x, y, w, h);
  }
}

MiniMap.Region = Region;
export default MiniMap;
