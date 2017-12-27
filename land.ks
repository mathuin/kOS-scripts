// land somewhere

RUNONCEPATH("lib.ks").

PRINT "Begin deorbit.".

SET DNODE TO ChangePeri(0).

ADD DNODE.

ExecuteNode().

// if this stage doesn't have a heat shield, ditch it
WHEN STAGE:RESOURCESLEX["Ablator"]:AMOUNT = 0 THEN {
    STAGE.
    PRESERVE.
}.

PRINT "Pop parachutes when appropriate.".
WHEN (NOT CHUTESSAFE) THEN {
    CHUTESSAFE ON.
    RETURN (NOT CHUTES).
}

PRINT "Pointing retrograde.".
SET MYSTEER TO RETROGRADE.
LOCK STEERING TO MYSTEER.
UNTIL SHIP:ALTITUDE < 5000 {
    SET MYSTEER TO RETROGRADE.
    WAIT 0.1.
}
UNLOCK STEERING.
