# XLR8PWM

Generates a PWM (Pulse Width Modulated) signal based on user-specified frequency and pulse width values

Generated frequency defaults to 8KHz, and can range from approximately 3.9KHz up to as high as 16MHz, with duty cycle from 0% to 100%

User inputs are floating-point values that represent the output period (1/frequency) and the output high pulse width, with a resolution of 1/16 microsecond (62.5ns)

It supports up to 32 channels with independent duty cycle control, and a common frequency across all channels

Functions include:
* enable() - turns on the specified channel
* disable() - turns off the specified channel
* setPeriod(float period) - specify the global period in decimal microseconds (truncated to next lower 62.5ns increment)
* setPulseWidth(float pulse) - specify the per-channel high pulse width in decimal microseconds (trncated to the next lower 62.5ns increment)
* getPeriod() - returns a float representing the global period
* getPulseWidth() - returns a float representing the per-channel pulse width
* isEnabled() - returns boolean representing whether the channel is enabled
