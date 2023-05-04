class RainArea {
  
  int dropnumber = 100;
  int x1, y1, x2, y2; 
  float flux_percentage;
  color bgcolor, dropmain, dropborder;
  String name;
  RainDrop drops[];
  float mds = 0;
  
  RainArea(int a, int b, int c, int d, String _name) {
    x1 = a;
    y1 = b;
    x2 = c;
    y2 = d;
    flux_percentage = 0;
    name = _name;
    bgcolor = color(0);
    dropmain = color(10,10,220);
    dropborder = color(180,180,220);
    drops = new RainDrop[dropnumber];
    for(int i=0; i<dropnumber; i++){
      drops[i] = new RainDrop(x2-x1, y2-y1, dropmain, dropborder);
    }
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
  
  float get_speed(){
    return mds;
  }
  
  void display() {
    
    pushMatrix();
      translate(x1, y1);
      //background
      noStroke();
      fill(bgcolor);
      rect(x1, y2, x2-x1, y2-y1);
      int current_nd = (int)flux_percentage;
      for(int i=0; i<current_nd; i++){
        if (drops[i].finished()){
          drops[i].restart();
        }
        drops[i].display();
        if(drops[i].get_speed() > mds) mds = drops[i].get_speed();
      }
    popMatrix(); 
    
  }
}
class RainDrop{
  color cmain, cborder;
  float x;
  float y;
  float area_width;
  float area_height;
  float yspeed;
  float life;
  
  RainDrop(int w, int h, color dropmain, color dropborder){
    area_width = w;
    area_height = h;
    cmain = dropmain;
    cborder = dropborder;
    x = random(0, area_width);
    y = random(0, area_height/10);
    yspeed = random(4,10);
    
  }
  
  boolean finished(){
    return (y >= area_height);
  }
  
  float get_speed(){
    return yspeed;
  }
  
  void restart(){
    x = random(0, area_width);
    y = random(0, area_height/10);
    yspeed = random(4,10);
  }
  
  void display(){
    //update dynamic
    y = y + yspeed;
    yspeed += 0.2;
    //draw it
    stroke(cborder);
    fill(cmain);
    strokeWeight(1);
    ellipse(x,y,5-5*(yspeed/15),5+5*(yspeed/15));
    
  }
    
}
