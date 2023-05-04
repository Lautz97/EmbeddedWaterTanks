class HandValve {
  
  int xpos, ypos, size; 
  float flux_percentage, orientation;
  color bgcolor, main, border;
  String name;
  
  HandValve(int x, int y, float o, String _name) {
    xpos = x;
    ypos = y;
    size = 40;
    orientation = o;
    name = _name;
    bgcolor = color(80,80,80);
    main = color(204,0,0);
    border = color(255,128,0);
  }
  
  float get_flux_percentage() {
    return flux_percentage;
  }
  
  void set_flux_percentage(float _flux) {
    if(_flux < 0){
      flux_percentage = 0;
    } else if(_flux > 100.0){
      flux_percentage = 100.0;
    } else {
      flux_percentage = _flux;
    }
    
  }
    
  void mWheel(MouseEvent event) {
    if((abs(mouseX - xpos) < (size/2)) & (abs(mouseY - ypos) < (size/2))){
      float e = event.getCount();
      float l = get_flux_percentage();
      l += 10*e;
      set_flux_percentage(l);
      //println(this.name + ": "+get_flux_percentage());
    }
  }
  
  void display() {
    pushMatrix();
      translate(xpos, ypos);
      rotate(orientation);
      //body
      stroke(bgcolor);
      strokeWeight(10.0);
      noFill();
      line(-15,0,15,0);
      //circle
      stroke(border);
      fill(main);
      strokeWeight(2.0);
      ellipse(0,0,18,18);
      // rotating lever 
      pushMatrix();
        stroke(main);
        strokeWeight(8.0);
        rotate(-HALF_PI*flux_percentage/100);
        line(0,0,0,20);
      popMatrix(); 
    popMatrix(); 
  }
}
