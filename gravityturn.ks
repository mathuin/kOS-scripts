// gravity turn
// inspired by https://forum.kerbalspaceprogram.com/index.php?/topic/114664-13-rocket-ascent-profile-and-gravity-turn/

// This script requires a vessel with the following characteristics:
// - TWR in excess of 1.5 at launch.
// - COM in front of COD.
//   "add 3 or 4 winglets with radial symmetry at bottom, and use fairings"

RUNONCEPATH("lib.ks").
PRINT "Begin launch with gravity turn.".

PRINT "Loading settings...".
SET SHIPSETS TO READJSON("0:turnsettings.json").
SET SHIPNAME TO SHIP:NAME.
IF SHIPSETS:HASKEY(SHIPNAME) {
    SET SETS TO SHIPSETS[SHIPNAME].
} ELSE {
    PRINT "Name not found!".
    SET SETS TO SHIPSETS["default"].
}

SET TWRGOAL TO SETS["TWRGOAL"].
SET ITA TO SETS["ITA"].
SET ITS TO SETS["ITS"].
SET ITT TO SETS["ITT"].
SET INTALT TO SETS["INTALT"].
SET APTIME TO SETS["APTIME"].
SET APALT TO SETS["APALT"].

CLEARSCREEN.
PRINT "Settings:".
PRINT "- Launch TWR goal: " + TWRGOAL.
PRINT "- Initial turn angle: " + ITA.
PRINT "- Initial turn speed: " + ITS.
PRINT "- Initial turn time: " + ITT.
PRINT "- Intermediate altitude: " + INTALT.
PRINT "- Apoapsis time: " + APTIME.
PRINT "- Apoapsis altitude: " + APALT.

SET MYSTEER TO HEADING(90, 90).
LOCK STEERING TO MYSTEER.
SET MYTHROT TO 1.0.
LOCK THROTTLE TO MYTHROT.

// Launch!
WHEN MAXTHRUST = 0 THEN {
    STAGE.
    PRESERVE.
}.

SET MODE TO "Launch".

UNTIL SHIP:ALTITUDE > INTALT {
    // Set throttle to desired TWR.
    SET TWR TO ShipTWR().
    IF TWR <= TWRGOAL {
        SET MYTHROT TO TWR.
    } ELSE {
        SET MYTHROT TO TWRGOAL / TWR.
    }.
    // Make initial turn.
    IF MODE = "Launch" AND SHIP:VELOCITY:SURFACE:MAG > ITS {
        PRINT "Reached initial turn speed, turning.".
        SET MODE TO "Turn".
        SET MYSTEER TO HEADING(90, 90-ITA).
        SET T0 TO TIME:SECONDS.
    }.
    // Hold turn for a period of time.
    IF MODE = "Turn" AND (TIME:SECONDS - T0 > ITT) {
        PRINT "Reached max turn time, drifting.".
        SET MODE TO "Drift".
        UNLOCK STEERING.
    }.
    WAIT 0.1.
}.

// At about 40 km, use pitch and throttle to keep Ap around 45 seconds ahead.
PRINT "Intermediate altitude reached, maintaining Ap distance".

// cannot use pitch at this time.
LOCK STEERING TO MYSTEER.
SET MYSTEER TO PROGRADE.

SET Kp TO 1.0.
SET Ki TO 0.0.  // 0.06.
SET Kd TO 0.0.
SET PID TO PIDLOOP(Kp, Ki, Kd, 0, 1).
SET PID:SETPOINT TO APTIME.

UNTIL SHIP:APOAPSIS > APALT {
    // PRINT "ETA:APOAPSIS: " + ETA:APOAPSIS AT (0, 14).
    // PRINT "PID:UPDATE: " + PID:UPDATE(TIME:SECONDS, ETA:APOAPSIS) AT (0, 15).
    SET MYSTEER TO PROGRADE.
    SET MYTHROT TO PID:UPDATE(TIME:SECONDS, ETA:APOAPSIS).
}

// Once target altitude is reached, coast.
// TODO: (little bursts when falling below said altitude)

PRINT "Apoapsis reached, cutting throttle and shutting down.".

// Securing throttle!
LOCK THROTTLE TO 0.
SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

PRINT "Circularizing orbit.".

SET MYNODE TO ChangePeri(SHIP:APOAPSIS).
ADD MYNODE.

ExecuteNode().
