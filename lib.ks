// lib of common functions.

// https://github.com/KSP-KOS/KOS/issues/942
FUNCTION ShipTWR
{
    LOCAL MTH IS SHIP:MAXTHRUST.
    LOCAL R IS SHIP:ALTITUDE+SHIP:BODY:RADIUS.
    LOCAL W IS SHIP:MASS * SHIP:BODY:MU / r / r.
    RETURN MTH/W.
}

// OrbitalVelocity implements the vis visa equation.
// Currently restricted to the present orbit.
FUNCTION OrbitalVelocity {
    PARAMETER HEIGHT, SMA.
    SET ORBIT TO SHIP:ORBIT.
    SET BODY TO ORBIT:BODY.
    RETURN SQRT(BODY:MU * (2/(HEIGHT + BODY:RADIUS) - 1/(SMA))).
}.

// https://www.reddit.com/r/Kos/comments/525hui/accurate_burns/
// Currently restricted to activated stage.
// NB: does not handle multi-stage burns!
FUNCTION BURN_TIME_CALC{
    SET EISP TO 0.
    SET MAXT TO 0.

    LIST ENGINES IN ENGINELIST.
    FOR ENG IN ENGINELIST {
        IF ENG:STAGE = STAGE:NUMBER {
            SET EISP TO EISP + ENG:ISP.
            SET MAXT TO MAXT + ENG:MAXTHRUST.
        }.
    }.

    PARAMETER CMAS, CVEL.
    LOCAL E IS CONSTANT():E.
    LOCAL G IS 9.80665. // Gravity for ISP Conv (why not constant)
    LOCAL I IS EISP * G. // ISP in m/s
    LOCAL M IS CMAS * 1000. // mass in kg
    LOCAL T IS MAXT * 1000. // Thurst in N.
    LOCAL F IS T/I. // fuel flow in kg/s.
    RETURN (M/F)*(1-E^(-CVEL/I)).
}.

// Change periapsis.
FUNCTION ChangePeri {
    PARAMETER TGTPERI.

    SET CURRAPVEL TO OrbitalVelocity(SHIP:APOAPSIS, ORBIT:SEMIMAJORAXIS).
    SET NEEDAPVEL TO OrbitalVelocity(SHIP:APOAPSIS, 0.5*(SHIP:APOAPSIS+BODY:RADIUS*2+TGTPERI)).
    SET CVEL TO NEEDAPVEL - CURRAPVEL.
    RETURN NODE(TIME:SECONDS+ETA:APOAPSIS, 0, 0, CVEL).
}.

// Change apoapsis.
FUNCTION ChangeApo {
    PARAMETER TGTAPO.

    PRINT "Current Pe: " + SHIP:PERIAPSIS.
    PRINT "Current Ap: " + SHIP:APOAPSIS.

    SET CURRPEVEL TO OrbitalVelocity(SHIP:PERIAPSIS, ORBIT:SEMIMAJORAXIS).
    PRINT "Current Pe velocity: " + CURRPEVEL.
    SET NEEDPEVEL TO OrbitalVelocity(SHIP:PERIAPSIS, 0.5*(TGTAPO+BODY:RADIUS*2+SHIP:PERIAPSIS)).
    PRINT "Need Pe velocity: " + NEEDPEVEL.
    SET CVEL TO NEEDPEVEL - CURRPEVEL.
    PRINT "Change velocity: " + CVEL.
    RETURN NODE(TIME:SECONDS+ETA:PERIAPSIS, 0, 0, CVEL).
}.

// Execute Next Node.
// NB: does not handle multi-stage burns.
FUNCTION ExecuteNode {
    set nd to nextnode.

    //print out node's basic parameters - ETA and deltaV
    print "Node in: " + round(nd:eta) + ", DeltaV: " + round(nd:deltav:mag).

    //calculate ship's max acceleration
    set max_acc to ship:maxthrust/ship:mass.

    // using a better method of burn duration calculation.
    set burn_duration to BURN_TIME_CALC(SHIP:MASS, ND:DELTAV:MAG).
    print "Estimated burn duration: " + round(burn_duration) + "s".

    // Warp if further than one minute.
    IF ND:ETA >= (burn_duration/2 + 60) {
        kuniverse:timewarp:warpto(time:seconds + nd:eta - burn_duration/2 - 60).
    }

    // Adjust direction at T-1 minute.
    // wait until nd:eta <= (burn_duration/2 + 60).

    set np to nd:deltav. //points to node, don't care about the roll direction.
    lock steering to np.

    //now we need to wait until the burn vector and ship's facing are aligned
    wait until vang(np, ship:facing:vector) < 0.25.

    //the ship is facing the right direction, let's wait for our burn time
    wait until nd:eta <= (burn_duration/2).

    //we only need to lock throttle once to a certain variable in the beginning of the loop, and adjust only the variable itself inside it
    set tset to 0.
    lock throttle to tset.

    set done to False.
    //initial deltav
    set dv0 to nd:deltav.
    until done
    {
        //recalculate current max_acceleration, as it changes while we burn through fuel
        set max_acc to ship:maxthrust/ship:mass.

        //throttle is 100% until there is less than 1 second of time left to burn
        //when there is less than 1 second - decrease the throttle linearly
        set tset to min(nd:deltav:mag/max_acc, 1).

        //here's the tricky part, we need to cut the throttle as soon as our nd:deltav and initial deltav start facing opposite directions
        //this check is done via checking the dot product of those 2 vectors
        if vdot(dv0, nd:deltav) < 0
        {
            print "End burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            lock throttle to 0.
            break.
        }

        //we have very little left to burn, less then 0.1m/s
        if nd:deltav:mag < 0.1
        {
            print "Finalizing burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            //we burn slowly until our node vector starts to drift significantly from initial vector
            //this usually means we are on point
            wait until vdot(dv0, nd:deltav) < 0.5.

            lock throttle to 0.
            print "End burn, remain dv " + round(nd:deltav:mag,1) + "m/s, vdot: " + round(vdot(dv0, nd:deltav),1).
            set done to True.
        }
    }
    unlock steering.
    unlock throttle.
    wait 1.

    //we no longer need the maneuver node
    remove nd.

    //set throttle to 0 just in case.
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.

}
