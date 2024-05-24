# Write aos and enter these
```console

GAME="RexNLeAt99gCM_wrx-kvwsQ-2bZj_n7qd-cdlcgYPtY"
Send({ Target = GAME, Action = "Register" })

```

# When you see "Player registered: "

```console

Send({ Target = GAME, Action = "Play" })

```

# Rules:
Wins If the sum is 7 - 11 in the first roll
Lose If the sum is 2 ,3 ,12 in the first roll

Determines a point and continues until the sum = point
If sum = 7 Game ends.

