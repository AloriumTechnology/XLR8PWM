#include "XLR8PWM.h"

static pwm_t pwms[MAX_PWMS];

uint8_t PwmCount = 0;

XLR8PWM::XLR8PWM() {
  if (PwmCount < MAX_PWMS) {
    this->pwmIndex = PwmCount++;
    pwms[this->pwmIndex].settings.en = false;
  }
  else {
    this->pwmIndex = INVALID_PWM; // too many pwms
  }
}

void XLR8PWM::enable() {
  pwms[this->pwmIndex].settings.en = true;
  PWMCR = (1 << 7) | (0 << 6) | (0 << 5) | (this->pwmIndex & 0x1f);
}

void XLR8PWM::disable() {
  pwms[this->pwmIndex].settings.en = false;
  PWMCR = (0 << 7) | (1 << 6) | (0 << 5) | (this->pwmIndex & 0x1f);
}

void XLR8PWM::setPulseWidth(float pulseWidth) {
  uint16_t pw16 = (uint16_t)(pulseWidth * 16);
  PWMPWH = (uint8_t)(pw16 >> 4);
  PWMPWL = (uint8_t)(pw16 & 0x000f);
  this->update();
}

void XLR8PWM::setPeriod(float period) {
  uint16_t per16 = (uint16_t)(period * 16);
  PWMPERH = (uint8_t)(per16 >> 4);
  PWMPERL = (uint8_t)(per16 & 0x000f);
  this->update();
}

float XLR8PWM::getPulseWidth() {
  float ret;
  ret = (PWMPWH << 4);
  ret &= (PWMPWL & 0x000f);
  ret = ret / 16;
  return ret;
}

float XLR8PWM::getPeriod() {
  float ret;
  ret = (PWMPERH << 4);
  ret &= (PWMPERL & 0x000f);
  ret = ret / 16;
  return ret;
}

bool XLR8PWM::isEnabled() {
  return pwms[this->pwmIndex].settings.en;
}

void XLR8PWM::update() {
  PWMCR = (1 << 7) | (0 << 6) | (1 << 5) | (this->pwmIndex & 0x1f);
}

