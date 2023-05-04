// This sketch is to demonstrate the possibility of creating a simulation part
// for some systems from exercises.
// Note: not everything is commented and maybe some unused vars are left

// import the library for managing serial communication
import processing.serial.*;

// NOTE: set here your port on which Arduino is connected
final String SERIAL_PORT_NAME = "COM4";
final int PORT_SPEED = 115200;

boolean first_stage = true;
boolean connected = false;
boolean ctrl_enabled = false;
char c;
int lf = 10;    // Linefeed in ASCII
String inStr = null;


float max_d_speed = 0;

Serial port;

//graphics vars
boolean gv_update_020 = false;
boolean gv_update_1 = false;

// some elements are coded in classes (OO programming), since we can have advantages
// both for variables and for graphics
WaterTank[] tanks;
HandValve[] valves;
RainArea ra;
ElectroValve ev;
ElectroPump ep;

//variables for subsystem states and values
int electro_valve_state = 0;
int pump_state = 0;
int led_state = 0;

// some temp variables
float tl_t1, tl_t2, tl_t3, tf_r, tf_p1, tf_pp, tf_pu;

 // Store device (controller) state
int devState;   
int last_sent_state = -1;

// to simulate water flowing, set some max pipe fluxes... the applyed fluxes will depend also on hand valves
float max_rain_flux = 25.0; //25 l/s, so fills T1 (500 l) in 20 seconds
float max_pipe1_flux = 15.0; //4.5 l/s, so T2 empty sensor (15% of 300l) in 10 seconds; incremented to 15
float max_pump_pipe_flux = 22.5; //22.5 l/s, T2 full sensor(90% of 300l = 270l) - empty sensor (15% of 300l = 45l) = 225l in 10 seconds 
float max_user_pipe_flux = 40.0; //40.0 l/s, T3 (1200 l) empty in 20 seconds

//timing variables
int update_ts = 0;
int last_1000ms_ts = 0;
int counter_1 = 0;
int now, delta_t;

//some common colors
color bg_general;
color brd_general;
color wires_general;
PFont font12;
PFont font24;
PImage imgSave;
PImage imgLoad;
PImage imgCtrl_enabled;
PImage imgCtrl_disabled;
int x_save;
int x_load;
int x_ctrl;
int y_icons; 

// used for saving/loading a "configuration"
JSONObject json;

void setup() {
  size(800, 600);
  surface.setTitle("Water tanks");
  surface.setResizable(false);
  surface.setLocation(1050, 100);
  
  font12 = createFont("Arial Bold", 12);
  font24 = createFont("Arial Bold", 24);
  textFont(font12);
  
  bg_general = color(180,180,220);
  brd_general = color(80,80,80);
  wires_general = color(204,102,0);
  
  //target height for images is 24 px
  imgSave = loadImage("disk.png");
  imgLoad = loadImage("folder.png");
  imgCtrl_enabled = loadImage("nano_on.png");
  imgCtrl_disabled = loadImage("nano_off.png");
  x_save = 22;
  x_load = 58;
  x_ctrl = 115;
  y_icons = 572;
  
  // here we want to connect to board, max 3 seconds
  now = millis();
  background(0);
  fill(255);
  textFont(font24);
  text("Connecting...", 100, 200);
  
  port = new Serial(this, SERIAL_PORT_NAME, PORT_SPEED);
  
  tanks = new WaterTank[3];
  tanks[0] = new WaterTank(120, 340, 180, 200, 500, "Tank1");
  tanks[1] = new WaterTank(380, 520, 120, 100, 300, "Tank2");
  tanks[1].enableSensorEmpty(15.0);
  tanks[1].enableSensorFull(90.0);
  tanks[2] = new WaterTank(650, 190, 240, 300, 1200, "Tank3");
  tanks[2].enableSensorFull(95.0);
  
  valves = new HandValve[4];
  valves[0] = new HandValve(100, 70, 0, "RainValve");
  valves[1] = new HandValve(200, 460, 0, "T1_outValve");
  valves[2] = new HandValve(380, 260, -HALF_PI, "T2_outValve");
  valves[3] = new HandValve(660, 410, 0, "T3_outValve");
  
  ra = new RainArea(40, 80, 170, 230, "Rain Area");
  
  ev = new ElectroValve(270, 460, 0, "Valve");
  ev.set_state(electro_valve_state);
  ep = new ElectroPump(380, 550, 0, "Pump");
  ep.set_state(pump_state);
  
  //TODO: load last saved settings...
  load_config();  
  
  update_ts = millis();
  last_1000ms_ts = update_ts;
}

void draw() {
  background(0);
  
  // check if it is time to wait for connection or not...
  // TODO: reorganize the code here, there are unnecessary vars and conditions
  if(first_stage==true){
    if((connected == false) && (millis() < now + 3500)){
      if(port.available() > 0){
        c = (char) port.read();
        if(c=='H' | c=='h'){
          connected = true;
          println("Device connected in "+(millis() - now)+" ms");
          //port.write('H');
        }
      }
      fill(255);
      textFont(font24);
      text("Connecting...", 100, 200);
    } 
    else first_stage = false;
    update_ts = millis();
    last_1000ms_ts = update_ts;
    return; //quit from "this" draw cycle
  }
  
  // useful to show coordinates to see where to place graphics
  // comment out when no more needed
  fill(176, 106, 53);
  textSize(16);
  textAlign(LEFT);
  text("x="+mouseX+" y="+mouseY, 680,20);
  
  
  
  
  //// *****************************************
  ////            RECEIVE MESSAGES
  //// *****************************************
  if(port.available() > 0) {
    inStr = port.readStringUntil(lf);
    if (inStr != null) {
      println("inStr="+inStr.trim());
      try {
        int ds =  Integer.parseInt(inStr.trim());
        if(ds>=0 & ds<=255){
          devState = ds;
          println("Device state: "+devState);          
        } else {
          println("received unknown state number");
        }
      } catch(NumberFormatException ex){
        println(devState);
        println("Exception in converting state");
      } 
    }
    
    
    //TODO: other messages?? ...
    //TODO: check state consistency??
  }
  
  //report in simulator device actuations only if "Controller enabled"
  // (sLED << 5) | (sP << 4) | (sV << 3) | (sT3F << 2) | (sT2F << 1) | (sT2E);
  if(ctrl_enabled){
    electro_valve_state = (devState & 0x08) >> 3;
    pump_state = (devState & 0x10) >> 4;
    led_state = (devState & 0x20) >> 5;
    //println(String.format("V:%d P:%d L:%d", electro_valve_state, pump_state, led_state));
    
    //report also in graphics...
    ev.set_state(electro_valve_state);
    ep.set_state(pump_state);
    //led.set_state(led_state);
  } else {
    led_state = 0;
  }
  
  // *****************************************
  //            EVOLUTIONS...
  // *****************************************
  
  //delta_t
  delta_t = millis() - update_ts;
  update_ts = millis();
  //println("delta_t = "+delta_t+" ms elapsed");
  
  //electro_valve_state
  //pump_state
  //max_rain_flux
  //max_pipe1_flux
  //max_pump_pipe_flux
  //max_user_pipe_flux
  
  float temp_float;
  
  //update tank1
  temp_float = tanks[0].get_liters();
  temp_float += max_rain_flux * valves[0].get_flux_percentage()/100.0 * delta_t/1000.0;
  if(electro_valve_state != 0) temp_float -= max_pipe1_flux * valves[1].get_flux_percentage()/100.0 * delta_t/1000.0;
  tanks[0].set_liters(temp_float);
  
  //update tank2
  temp_float = tanks[1].get_liters();
  if( (tanks[0].get_liters()>0) & (electro_valve_state != 0) ) temp_float += max_pipe1_flux * valves[1].get_flux_percentage()/100.0 * delta_t/1000.0;
  if(pump_state != 0) temp_float -= max_pump_pipe_flux * valves[2].get_flux_percentage()/100.0 * delta_t/1000.0;
  tanks[1].set_liters(temp_float);
  
  //update tank3
  temp_float = tanks[2].get_liters();
  if( (tanks[1].get_liters()>0) & (pump_state != 0) ) temp_float += max_pump_pipe_flux * valves[2].get_flux_percentage()/100.0 * delta_t/1000.0;
  temp_float -= max_user_pipe_flux * valves[3].get_flux_percentage()/100.0 * delta_t/1000.0;
  tanks[2].set_liters(temp_float);
  
  
  //timing events
  if(millis() >= last_1000ms_ts + 1000){
    last_1000ms_ts = millis();
    counter_1 += 1;
    
    //set a flag used later for graphics
    gv_update_1 = true;
    
    //code to exec every 1 sec
    //just a test... comment later (you will notice leaps)
    //println("now="+last_1000ms_ts+": 1000 ms elapsed");
    
    tl_t1 = tanks[0].get_liters();
    tl_t2 = tanks[1].get_liters();
    tl_t3 = tanks[2].get_liters();
    tf_r = max_rain_flux * valves[0].get_flux_percentage()/100.0;
    if( (tanks[0].get_liters()>0) & (electro_valve_state != 0) ){
      tf_p1 = max_pipe1_flux * valves[1].get_flux_percentage()/100.0;
    } else {
      tf_p1 = 0;
    }
    if( (tanks[1].get_liters()>0) & (pump_state != 0) ){
      tf_pp = max_pump_pipe_flux * valves[2].get_flux_percentage()/100.0;
    } else {
      tf_pp = 0;
    }
    if( (tanks[2].get_liters()>0) ){
      tf_pu = max_user_pipe_flux * valves[3].get_flux_percentage()/100.0;
    } else {
      tf_pu = 0;
    }
  }  
  
  
  //// *****************************************
  ////    SEND MESSAGES TO THE CONTROLLER
  //// *****************************************
  
  // (sLED << 5) | (sP << 4) | (sV << 3) | (sT3F << 2) | (sT2F << 1) | (sT2E);
  // BUT we send only lower 3 bits, related to level sensors
  if(ctrl_enabled){
    int x = 0;
    x += (tanks[1].sensorEmptyState())?1:0;
    x += (tanks[1].sensorFullState())?2:0;
    x += (tanks[2].sensorFullState())?4:0;
    
    if(x != last_sent_state){
      last_sent_state = x;
      String s = (char(x + 48)+"\n");
      println(String.format("Sending level sensors states: %d", x));
      port.write(s);
    }
  }
  
  
  
  
  
  
  
  
  //// *****************************************
  ////    MANAGE ALL GRAPHIC RELATED STUFF
  //// *****************************************
  
  
  //rain area, it will be covered by cloud
  ra.set_flux_percentage(valves[0].get_flux_percentage());
  ra.display();
  //if(ra.get_speed() > max_d_speed){
  //  max_d_speed = ra.get_speed();
  //  println("Max drop speed = " + max_d_speed);
  //}
  
  //cloud
  stroke(126);
  strokeWeight(3.0);
  noFill();
  ellipse(120,70,140,80);
  ellipse(160,45,70,40);
  ellipse(100,105,70,40);
  ellipse(70,75,110,60);
  fill(250);
  noStroke();
  ellipse(120,70,140,80);
  ellipse(160,45,70,40);
  ellipse(100,105,70,40);
  ellipse(70,75,110,60);
  
  //pipe1
  stroke(126);
  strokeWeight(8.0);
  noFill();
  line(180,440,180,450);
  arc(190,450,20,20,HALF_PI,PI);
  line(190,460,330,460);
  
  //pipe3
  stroke(126);
  strokeWeight(8.0);
  noFill();
  line(600,340,600,400);
  arc(610,400,20,20,HALF_PI,PI);
  line(610,410,710,410);
  
  //water tanks
  //call directly their .display() method
  for(int i=0; i<3; i++){
    tanks[i].display();
  }
  
  //pipe2
  stroke(126);
  strokeWeight(8.0);
  noFill();
  line(380,550,380,40);
  arc(390,40,20,20,PI,PI+HALF_PI);
  line(390,30,540,30);
  
  //hand valves
  for(int i=0; i<4; i++){
    valves[i].display();
  }
  
  //electro pump and electro valve
  //call directly their .display() method
  ev.display();
  ep.display();
  
  //make a binding for onboard_led
  fill(bg_general);
  stroke(brd_general);
  strokeWeight(4);
  rect(420,360,50,70,3);
  if(ctrl_enabled){
    if(led_state != 0) fill(color(0,255,0));
    else fill(color(0,153,0));
  } else {
    fill(color(84,102,84));
  }
  strokeWeight(2);
  circle(445,395,20);
  
  textFont(font12);
  fill(0);
  textAlign(CENTER);
  text("CTRL", 445, 380);
  textAlign(LEFT);
  
  //wires... color(204,102,0)
  stroke(wires_general);
  strokeWeight(2);
  line(380,530,380,380); line(380,380,420,380); //pump
  line(270,460,270,375); line(270,375,420,375); //valve
  line(440,480,480,480); line(480,480,480,385); line(480,385,470,385); //T2F
  line(440,555,485,555); line(485,555,485,380); line(485,380,470,380); //T2E
  line(770,55,790,55);   line(790,55,790,375);  line(790,375,470,375); //T3F
  
  //labels near tanks and valves
  textFont(font12);
  fill(255); 
  text(String.format("TANK1: %.1f L", tl_t1), 45, 460);
  text(String.format("TANK2: %.1f L", tl_t2), 340, 590);
  text(String.format("TANK3: %.1f L", tl_t3), 680, 360);
  fill(0);
  text(String.format("Rain: %.1f L/s", tf_r), 100, 55);
  fill(255);
  text(String.format("F: %.1f L/s", tf_p1), 170, 500);
  text(String.format("F: %.1f L/s", tf_pp), 400, 280);
  text(String.format("F: %.1f L/s", tf_pu), 630, 450);
      
  
  // load, save and enable/disable ctrl icons...
  fill(bg_general);
  stroke(brd_general);
  strokeWeight(2);
  rect(3,552,150,38,5);
  imageMode(CENTER);
  image(imgLoad, x_load, y_icons);         // center at 22, 572
  image(imgSave, x_save, y_icons);         // center at 58, 572
  if(ctrl_enabled)
    image(imgCtrl_enabled, x_ctrl, y_icons); // center at 115, 572
  else
    image(imgCtrl_disabled, x_ctrl, y_icons);
  
  
  //there are no "update once every second" in this sketch graphics...
  //just left if we want to add something
  if(gv_update_1){
    //...
  }
  gv_update_1 = false;
}

void save_config(){
  json = new JSONObject();
  
  json.setFloat("Tank1", tanks[0].get_liters());
  json.setFloat("Tank2", tanks[1].get_liters());
  json.setFloat("Tank3", tanks[2].get_liters());
  json.setFloat("RainValve", valves[0].get_flux_percentage());
  json.setFloat("T1_outValve", valves[1].get_flux_percentage());
  json.setFloat("T2_outValve", valves[2].get_flux_percentage());
  json.setFloat("T3_outValve", valves[3].get_flux_percentage());
  
  saveJSONObject(json, "data/config.json");
}

void load_config(){
  
  json = loadJSONObject("data/config.json");
  
  tanks[0].set_liters(json.getFloat("Tank1"));
  tanks[1].set_liters(json.getFloat("Tank2"));
  tanks[2].set_liters(json.getFloat("Tank3"));
  valves[0].set_flux_percentage(json.getFloat("RainValve"));
  valves[1].set_flux_percentage(json.getFloat("T1_outValve"));
  valves[2].set_flux_percentage(json.getFloat("T2_outValve"));
  valves[3].set_flux_percentage(json.getFloat("T3_outValve"));
}
  
  
  
// **********************************
//   asynch event management
// **********************************

// this next is what should be executed on mouse-pressed
void mousePressed() {
  // notify electro valve and pump of the event
  // they will evaulate if are involved or not depending on their position
  if(!ctrl_enabled){
    electro_valve_state = ev.mPressed();
    pump_state = ep.mPressed();
  }
  // here, instead, directly compare coordinates for some elements
  // that have not been coded into classes
  if(abs(mouseY-y_icons)<=12){
    if(abs(mouseX-x_load)<=12){
      //load
      load_config();
    }
    if(abs(mouseX-x_save)<=12){
      //save
      save_config();
    }
    if(abs(mouseX-x_ctrl)<=30){
      //toggle ctrl
      ctrl_enabled = !ctrl_enabled;
      println("Controller is "+((ctrl_enabled)?"ENABLED":"DISABLED"));
    }
  }
}

void mouseReleased() {
  //you want to put something on mouse released??
}

void keyPressed() {
  
  println(keyCode);
  //numerical keys of the keyboard used to send "states" in the first
  //stage of coding this sketch, you do not need them if using graphics
  if((keyCode >= 48) & (keyCode <= 57)){
    String s = (str(keyCode - 48)+"\n");
    port.write(s);
    println("Sending: "+s);
  }
  if((keyCode >= 96) & (keyCode <= 105)){
    String s = (str(keyCode - 96)+"\n");
    port.write(s);
    println("Sending: "+s);
  }
  //switch(key) {
    
  //  case(32): // BARSPACE
  //    println("BARSPACE");
  //    //do something
  //  break;
  //  case('0'): // 0
  //    //do something else...
  //  break;
  //  case('+'): // +
  //    //increment something
  //  break;
  //  case('-'): // -
  //    //or decrement it
  //  break;
  //  default:
  //    println(keyCode);
  //}
}

//this is used to quickly set water tank level with mouse wheel
//only if mouse is over the tank, this coordinate control is
//demanded to each tank, so we have to "notify" them all.
//Also hand valves react to mouse wheel for open/close,
//so notify them also the wheel event
void mouseWheel(MouseEvent event) {
  for(int i=0; i<3; i++){
    tanks[i].mWheel(event);
  }
  for(int i=0; i<4; i++){
    valves[i].mWheel(event);
  }
}
