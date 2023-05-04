class WaterTank {
  
  int xpos, ypos, twidth, theight; 
  float capacity, liter;
  boolean overflow, has_sensor_full, has_sensor_empty;
  float sensor_full_percentage, sensor_empty_percentage;
  color water, nowater, border;
  String name;
  
  WaterTank(int x, int y, int w, int h, int _capacity, String _name) {
    xpos = x;
    ypos = y;
    twidth = w;
    theight = h;
    capacity = _capacity;
    liter = 0;
    overflow = false;
    has_sensor_full = false;
    has_sensor_empty = false;
    name = _name;
    water = color(10,10,220);
    nowater = color(180,180,220);
    border = color(128,128,128);
  }
  
  float get_capacity() {
    return capacity;
  }
  
  void set_liters(float _liter) {
    if(_liter < 0){
      liter = 0;
      overflow = false;
    } else if(_liter > capacity*1.05){
      liter = capacity*1.05;
      overflow = true;
    } else {
      liter = _liter;
      overflow = false;
    }
    
  }
  
  float get_liters() {
    return liter;
  }
  
  void enableSensorFull(float level_percentage){
    has_sensor_full = true;
    sensor_full_percentage = level_percentage % 100.0;
  }
  void enableSensorEmpty(float level_percentage){
    has_sensor_empty = true;
    sensor_empty_percentage = level_percentage % 100.0;
  }
  void disableSensorFull(){
    has_sensor_full = false;
  }
  void disableSensorEmpty(){
    has_sensor_empty = false;
  }
  
  boolean sensorFullState(){
    return (has_sensor_full & ((100.0*liter/capacity)>=sensor_full_percentage));
  }
  boolean sensorEmptyState(){
    return (has_sensor_empty & ((100.0*liter/capacity)>=sensor_empty_percentage));
  }
  
  void mWheel(MouseEvent event) {
    if((abs(mouseX - xpos) < (twidth/2)) & (abs(mouseY - ypos) < (theight/2))){
      float e = -1 * event.getCount();
      float l = get_liters();
      l += 10*e;
      set_liters(l);
      //println(this.name + ": "+get_liters());
    }
  }
  
  void display() {
    imageMode(CENTER); 
    //tank background "nowater"
    fill(nowater);
    stroke(nowater);
    strokeWeight(0);
    rect(xpos-twidth/2, ypos-theight/2, twidth, theight, 0, 0, 20, 20);
    
    //water
    float wlev = theight * (liter/(capacity * 1.0));
    fill(water);
    stroke(water);
    strokeWeight(0);
    rect(xpos-twidth/2, (ypos-theight/2)+(theight-wlev), twidth, wlev, 0, 0, 20, 20);
    
    //black rounded border inverted
    fill(0);
    stroke(0);
    strokeWeight(0);
    rect(xpos-twidth/2, ypos+theight/2, 0, 0, 0, -20, 0, 0);
    rect(xpos+twidth/2, ypos+theight/2, 0, 0, -20, 0, 0, 0);
    
    //border
    noFill();
    stroke(126);
    strokeWeight(4.0);
    rect(xpos-twidth/2, ypos-theight/2, twidth, theight, 0, 0, 20, 20);
    
    //sensors
    if(has_sensor_full){
      color c = (sensorFullState())? color(0,255,0):color(255,0,0);
      fill(c);
      stroke(126);
      strokeWeight(1);
      rect(xpos+twidth/2-10, ypos-theight/2+(theight*(1-sensor_full_percentage/100))-5, 20, 10);
    }
    if(has_sensor_empty){
      color c = (sensorEmptyState())? color(0,255,0):color(255,0,0);
      fill(c);
      stroke(126);
      strokeWeight(1);
      rect(xpos+twidth/2-10, ypos-theight/2+(theight*(1-sensor_empty_percentage/100))-5, 20, 10);
    }
    
  }
}
