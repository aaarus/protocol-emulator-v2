#define PIN0 0

// Open-drain outputs
CONFIG_GPIO PIN0, OUTPUT, OPEN_DRAIN, TIMED

//idle high
LOAD_TICK_INC 100
SET_GPIO PIN0
WAIT_TICK //what is happening

//we need a manual tick, or temporary tick override of some sorts. does set override tick?

LOAD_TICK_INC 100

//sof
CLR_GPIO PIN0

SET_GPIO_TX TX0, PIN0
LOAD_TX TX0 0xDA


//just 1byte arbitration test

LOOP 8
    SHIFT_OUT TX0
    WAIT_TICK

    DELAY 70 //wont be exactly 70. need to fix later

    //check if we lost arbitration
    BRANCH BIT_SET, LAST_TX0, B1
    BRANCH ALWAYS B3
    B1: BRANCH BIT_CLEAR, SAMPLED_GPIO, B2
    BRANCH ALWAYS B3
    B2: BRANCH ALWAYS QUIT
    B3:  //b3 means we did not lose arbitration, so we can continue sending data
LOOP_END


QUIT: BRANCH ALWAYS QUIT





