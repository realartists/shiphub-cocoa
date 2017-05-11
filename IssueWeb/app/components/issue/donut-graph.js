import React, { createElement as h } from 'react'

/* Props:
  { parts: [ { color: "...", count: ... }, ... ]
 */
class DonutGraph extends React.Component {
  
  shouldComponentUpdate(nextProps, nextState) {
    var nextParts = Array.from(nextProps.parts);
    var parts = Array.from(this.props.parts);
    
    if (nextParts.length != parts.length) return true;
    
    function sortByColor(a, b) {
      if (a.color < b.color) return -1;
      else if (a.color == b.color) return 1;
      else return 0;
    }
    
    nextParts.sort(sortByColor);
    parts.sort(sortByColor);
    
    for (var i = 0; i < parts.length; i++) {
      var a = parts[i];
      var b = nextParts[i];
      
      if (a.color != b.color || a.count != b.count) return true;
    }
    
    return false; // props are the same
  }

  render() {
    var scale = window.devicePixelRatio;
    var size = this.props.size;
    return h('canvas', { 
      ref:'canvas', 
      width: size*scale, 
      height: size*scale, 
      style: { width: `${size}px`, height: `${size}px` } 
    });
  }
  
  componentDidMount() {
    this.draw();
  }
  
  componentDidUpdate() {
    this.draw();
  }
  
  draw() {
    var el = this.refs.canvas;
    if (!el) return;
    
    var { size, parts } = this.props;
    
    var ctx = el.getContext('2d');
    ctx.save();
    
    var scale = window.devicePixelRatio * size;
    ctx.scale(scale, scale);
    ctx.lineWidth = 1.0/scale;
            
    // clear context
    ctx.clearRect(0, 0, 1, 1);
        
    // compute arclen for each part in parts
    var sum = parts.reduce((accum, p) => accum + p.count, 0);
    
    if (sum == 0) {
      return; // nothing to draw
    }
    
    var arclens = parts.map(p => p.count / sum);
    
    // draw arcs
    var offset = 0;
    for (var i = 0; i < parts.length; i++) {
      var color = parts[i].color;
      var len = arclens[i];
      
      if (len == 0) continue;
      
      ctx.fillStyle = color;
      
      var start = 3.0*Math.PI/2.0 + (Math.PI*2.0*offset);
      var end = 3.0*Math.PI/2.0 + (Math.PI*2.0*(offset+len));
      
      ctx.beginPath();
      ctx.moveTo(0.5, 0.5);
      ctx.arc(0.5, 0.5, 0.5, start, end);
      ctx.fill();
      
      offset += len;
    }
    
    // knock out the center
    {
      ctx.save();
      
      ctx.beginPath();
      ctx.arc(0.5, 0.5, 0.5*0.6, 0, Math.PI*2.0);
      ctx.clip();
      ctx.clearRect(0, 0, 1, 1);
      
      ctx.restore();
    }
    
    ctx.restore();
  }
}

export default DonutGraph;
