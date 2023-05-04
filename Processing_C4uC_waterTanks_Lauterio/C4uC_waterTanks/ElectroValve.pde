class ElectroValve {
  
  int xpos, ypos, size; 
  float orientation;
  color cmain_on, cmain_off, cborder;
  int state;
  String name;
  
  ElectroValve(int x, int y, float o, String _name) {
    xpos = x;
    ypos = y;
    size = 50;
    orientation = o;
    name = _name;
    state = 0;
    cmain_on = color(255,128,0);
    cmain_off = color(204,204,0);
    cborder = color(80,80,80);
  }
  
  void set_state(int _state) {
    state = _state;
  }
  
  int get_state() {
    return state;
  }
    
  int mPressed() {
    if((abs(mouseX - xpos) < (size/2)) & (abs(mouseY - ypos) < (size/2))){
      if(state != 0) state = 0;
      else state = 1;
    }
    //if(state != 0) println("EV_ON");
    return state;
  }
  
  void display() {
    pushMatrix();
      translate(xpos, ypos);
      rotate(orientation);
      //body
      stroke(cborder);
      strokeWeight(2.0);
      if(state != 0) fill(cmain_on);
      else fill(cmain_off);
      triangle(-25, -12.5, -25, 12.5, 0, 0);
      triangle(25, -12.5, 25, 12.5, 0, 0);
    popMatrix(); 
  }
}
