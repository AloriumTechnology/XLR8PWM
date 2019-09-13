#ifndef XLR8_PWM_H
#define XLR8_PWM_H

#ifdef ARDUINO_XLR8

#include <Arduino.h>

#define PWMCR   _SFR_MEM8(0xD7)
#define PWMPERH _SFR_MEM8(0xD8)
#define PWMPERL _SFR_MEM8(0xD9)
#define PWMPWH  _SFR_MEM8(0xDA)
#define PWMPWL  _SFR_MEM8(0xDB)

#define MAX_PWMS 32
#define INVALID_PWM 255

typedef struct {
  bool     en;
} PWMSettings_t;

typedef struct {
  PWMSettings_t settings;
} pwm_t;

class XLR8PWM {
public:
  XLR8PWM();
  void enable();
  void disable();
  void setPulseWidth(float pulse);
  void setPeriod(float period);
  float getPulseWidth();
  float getPeriod();
  bool isEnabled();
private:
  uint8_t pwmIndex;
  void update();
};

#else
#error "XLR8PWM library requires Tools->Board->XLR8xxx selection."
#endif // ARDUINO_XLR8

#endif // XLR8_PWM_H
