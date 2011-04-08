// Bluetooth-bot v1
// Arduino Robotics unofficial chapter 14
// use Bluetooth Mate serial adapter to receive commands from PC
// Arduino decodes commands into motor movements
// Creates high-speed wireless serial link for robot control using keyboard
// Uses keys "i" = forward, "j" = left, "k" = reverse, and "l" = right
// speed control is also implemented using "," = speed down, "." = speed up, and "/" = max speed.


// L298 motor control variables
int M1_A = 12;
int M1_PWM = 11;
int M1_B = 10;

int M2_A = 4;
int M2_PWM = 3;
int M2_B = 2;


// LED pin attached to Arduino D13
int LED = 13;

// variable to store serial data
//int incomingByte = 0;

// variable to store speed value
int speed_val = 65;
int band_pass = 190;
int deadband_high = 10;
int deadband_low = deadband_high * -1;
int low = -70;
int high = 70;

int X_accel_raw;
int Y_accel_raw;
int x;
int y;
int left;
int right;


String readString;
char command_end = 'Z';
char command_begin = '$';

char current_char;


//////////////////////////////


void setup(){

  TCCR2B = TCCR2B & 0b11111000 | 0x01; // change PWM frequency for pins 3 and 11 to 32kHz so there will be no motor whining

  // Start serial monitor at 115,200 bps
  Serial.begin(115200);

  // declare outputs
  pinMode(LED, OUTPUT);

  pinMode(M1_A, OUTPUT);
  pinMode(M1_PWM, OUTPUT);
  pinMode(M1_B, OUTPUT);

  pinMode(M2_A, OUTPUT);
  pinMode(M2_PWM, OUTPUT);
  pinMode(M2_B, OUTPUT);

  // turn motors Off by default
  m1_stop();
  m2_stop();

  delay(500);

  readString = "";

}

////////////////////////////////////


void handle_command(String readString){

  if(readString.substring(0,1) == "X"){
    char temp[20];
    readString.substring(1).toCharArray(temp, 19);
    int x_val = atoi(temp);
    X_accel_raw = x_val;    
  }
  else if(readString.substring(0,1) == "Y"){
    char temp[20];
    readString.substring(1).toCharArray(temp, 19);
    int y_val = atoi(temp);
    Y_accel_raw = y_val;
  } 
  else {
    //X_accel_raw = 0;
    //Y_accel_raw = 0;
  }

  /*
  Serial.print("X_accel_raw: ");
   Serial.print(X_accel_raw);
   Serial.print("     ");
   Serial.print("Y_accel_raw: ");
   Serial.print(Y_accel_raw);
   Serial.print("     ");
   */
}



void loop(){


  while (Serial.available()) {
    current_char = Serial.read();  //gets one byte from serial buffer

    if(current_char == command_begin){ // when we get a begin character, start reading
      readString = "";
      while(current_char != command_end){ // stop reading when we get the end character
        current_char = Serial.read();  //gets one byte from serial buffer
        if(current_char != command_end){
          //Serial.println(current_char);
          readString += current_char;
          delay(10);
        }
      }

      Serial.println(readString);
      if(current_char == command_end){ // since we have the end character, send the whole command to the command handler and reset readString.
        //Serial.println("foo");
        handle_command(readString);
        readString = "";
      }
    } 
  }

  //  Y_accel_raw = analogRead(0);
  //  Y_accel_raw = map(Y_accel_raw, 0, 1023, -70, 70); 

  x = map(X_accel_raw, low, high, -speed_val, speed_val); 
  y = map(Y_accel_raw ,low, high, -speed_val, speed_val); 

  // Now we can check the accelerometer values to see what direction the robot should go:

  if (y > deadband_high) {  // if the Y-axis input is above the upper threshold, go FORWARD 

    // Going Forward, now check to see if we should go straight ahead,turn left, or turn right.
    if (x > deadband_high) { // go forward while turning right proportional to the R/C left/right input
      left = y + band_pass;
      right = (y - x)  + band_pass;
      test_speed();
      m1_forward(left);
      m2_forward(right);
      // quadrant 1 - forward and to the right
    }
    else if (x < deadband_low) {   // go forward while turning left proportional to the left/right input
      left = (y - (x * -1)) + band_pass;  // remember that in this case, x will be a negative number, so multiply by -1
      right = y + band_pass;
      test_speed();
      m1_forward(left);
      m2_forward(right);
      // quadrant 2 - forward and to the left
    }
    else {   // left/right stick is centered, go straight forward
      left = y + band_pass;
      right = y + band_pass;
      test_speed();
      m1_forward(left);
      m2_forward(right);
      // go forward along Y axis
    }
  }

  else if (y < deadband_low) {    // otherwise, if the Up/Down R/C input is below lower threshold, go BACKWARD

    // remember that x is below deadband_low, it will always be a negative number, we need to multiply it by -1 to make it positive.
    // now check to see if left/right input from R/C is to the left, to the right, or centered.
    if (x > deadband_high) { // // go backward while turning right proportional to the R/C left/right input
      left = (y * -1) + band_pass;
      right = ((y * -1) - x) + band_pass;
      test_speed();
      m1_reverse(left);
      m2_reverse(right);
      // quadrant 4 - go backwards and to the right
    }
    else if (x < deadband_low) {   // go backward while turning left proportional to the R/C left/right input
      left = ((y * -1) - (x * -1)) + band_pass;
      right = (y * -1) + band_pass;
      test_speed();
      m1_reverse(left);
      m2_reverse(right);   
      // quadrant 3 - go backwards and to the left
    }			
    else {   // left/right stick is centered, go straight backwards
      left = (y * -1) + band_pass; 
      right = (y * -1) + band_pass; 
      test_speed();
      m1_reverse(left);
      m2_reverse(right);
      // go straight backwards along x axis
    }
  }

  else {     // if neither of the above 2 conditions is met, then X (Up/Down) R/C input is centered (neutral)

    if (x > deadband_high) { // // go backward while turning right proportional to the R/C left/right input
      left = x + band_pass;
      right = left;
      test_speed();
      m1_forward(left);
      m2_reverse(right);
      // quadrant 4 - go backwards and to the right
    }
    else if (x < deadband_low) {   // go backward while turning left proportional to the R/C left/right input
      left = (x * -1) + band_pass;
      right = left;
      test_speed();
      m1_reverse(left);
      m2_forward(right);  
      // quadrant 3 - go backwards and to the left
    }			 

    else{
      // Stop motors!
      left = 0;
      right = 0;
      m1_stop();
      m2_stop();
    }

  }


//  Serial.print("r: ");
//  Serial.print(right);
//  Serial.print("     ");
//  Serial.print("l: ");
//  Serial.print(left);
//  Serial.println("     ");
//  delay(300);

}

/////////// motor functions ////////////////

void m1_reverse(int x){
  digitalWrite(M1_B, LOW);
  digitalWrite(M1_A, HIGH);
  analogWrite(M1_PWM, x);
}

void m1_forward(int x){
  digitalWrite(M1_A, LOW);
  digitalWrite(M1_B, HIGH);
  analogWrite(M1_PWM, x);
}

void m1_stop(){
  digitalWrite(M1_B, LOW);
  digitalWrite(M1_A, LOW);
  digitalWrite(M1_PWM, LOW);
}

void m2_forward(int y){
  digitalWrite(M2_B, LOW);
  digitalWrite(M2_A, HIGH);
  analogWrite(M2_PWM, y);
}

void m2_reverse(int y){
  digitalWrite(M2_A, LOW);
  digitalWrite(M2_B, HIGH);
  analogWrite(M2_PWM, y);
}

void m2_stop(){
  digitalWrite(M2_B, LOW);
  digitalWrite(M2_A, LOW);
  digitalWrite(M2_PWM, LOW);
}




void test_speed(){
  // constrain speed value to between 0-255
  if (speed_val > 250){
    speed_val = 255;
    //Serial.println(" MAX ");
  }
  if (speed_val < 0){
    speed_val = 0;
    //Serial.println(" MIN ");
  }

}


