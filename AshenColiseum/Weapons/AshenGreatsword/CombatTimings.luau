-- Original Ashen Oath animation timings. Seconds, 30 fps baked clips.
-- Animation asset IDs are assigned after publishing in Roblox Studio.
return {
    ["Idle"] = {
        Duration = 3.2, Loop = true,
        SuggestedTravel = 0,
        Markers = {
        },
    },
    ["WalkForward"] = {
        Duration = 1.2, Loop = true,
        SuggestedTravel = 0,
        Markers = {
            ["FootL"] = 0,
            ["FootR"] = 0.6,
        },
    },
    ["WalkBackward"] = {
        Duration = 1.3333333333333333, Loop = true,
        SuggestedTravel = 0,
        Markers = {
            ["FootL"] = 0,
            ["FootR"] = 0.66,
        },
    },
    ["StrafeLeft"] = {
        Duration = 1.2666666666666666, Loop = true,
        SuggestedTravel = 0,
        Markers = {
            ["FootL"] = 0,
            ["FootR"] = 0.64,
        },
    },
    ["StrafeRight"] = {
        Duration = 1.2666666666666666, Loop = true,
        SuggestedTravel = 0,
        Markers = {
            ["FootL"] = 0,
            ["FootR"] = 0.64,
        },
    },
    ["RunForward"] = {
        Duration = 0.8666666666666667, Loop = true,
        SuggestedTravel = 0,
        Markers = {
            ["FootL"] = 0,
            ["FootR"] = 0.43,
        },
    },
    ["Equip"] = {
        Duration = 1.8, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["WeaponVisible"] = 0,
            ["LeftGrip"] = 1.0,
            ["Ready"] = 1.65,
        },
    },
    ["Unequip"] = {
        Duration = 1.6, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["LeftRelease"] = 0.55,
            ["WeaponHidden"] = 1.5,
        },
    },
    ["Light_01"] = {
        Duration = 1.4, Loop = false,
        SuggestedTravel = 0.6,
        Markers = {
            ["Windup"] = 0,
            ["Swing"] = 0.46,
            ["ActiveStart"] = 0.52,
            ["ActiveEnd"] = 0.75,
            ["ComboOpen"] = 0.9,
            ["RecoveryEnd"] = 1.4,
        },
    },
    ["Light_02"] = {
        Duration = 1.4666666666666666, Loop = false,
        SuggestedTravel = 0.6,
        Markers = {
            ["Windup"] = 0,
            ["Swing"] = 0.51,
            ["ActiveStart"] = 0.58,
            ["ActiveEnd"] = 0.81,
            ["ComboOpen"] = 0.95,
            ["RecoveryEnd"] = 1.48,
        },
    },
    ["Light_03"] = {
        Duration = 1.8666666666666667, Loop = false,
        SuggestedTravel = 0.9,
        Markers = {
            ["Windup"] = 0,
            ["Swing"] = 0.67,
            ["ActiveStart"] = 0.78,
            ["ActiveEnd"] = 1.02,
            ["RecoveryEnd"] = 1.88,
        },
    },
    ["Heavy_Charge"] = {
        Duration = 1.1, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["ChargeStart"] = 0,
            ["ChargeReady"] = 1.1,
        },
    },
    ["Heavy_Hold"] = {
        Duration = 1.4, Loop = true,
        SuggestedTravel = 0,
        Markers = {
        },
    },
    ["Heavy_Release"] = {
        Duration = 1.5333333333333334, Loop = false,
        SuggestedTravel = 1.1,
        Markers = {
            ["Swing"] = 0.14,
            ["ActiveStart"] = 0.28,
            ["Impact"] = 0.41,
            ["ActiveEnd"] = 0.51,
            ["RecoveryEnd"] = 1.52,
        },
    },
    ["Running_Attack"] = {
        Duration = 1.6666666666666667, Loop = false,
        SuggestedTravel = 2,
        Markers = {
            ["Swing"] = 0.34,
            ["ActiveStart"] = 0.43,
            ["ActiveEnd"] = 0.66,
            ["RecoveryEnd"] = 1.65,
        },
    },
    ["Thrust"] = {
        Duration = 1.6, Loop = false,
        SuggestedTravel = 1.1,
        Markers = {
            ["Swing"] = 0.4,
            ["ActiveStart"] = 0.51,
            ["ActiveEnd"] = 0.79,
            ["RecoveryEnd"] = 1.6,
        },
    },
    ["Guard_Enter"] = {
        Duration = 0.4, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["GuardOn"] = 0.26,
        },
    },
    ["Guard_Loop"] = {
        Duration = 2.0, Loop = true,
        SuggestedTravel = 0,
        Markers = {
        },
    },
    ["Guard_Exit"] = {
        Duration = 0.4666666666666667, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["GuardOff"] = 0,
        },
    },
    ["Guard_Impact"] = {
        Duration = 0.6666666666666666, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["Impact"] = 0.05,
            ["RecoveryEnd"] = 0.66,
        },
    },
    ["Guard_Break"] = {
        Duration = 1.9, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["GuardOff"] = 0,
            ["StaggerStart"] = 0.12,
            ["RecoveryEnd"] = 1.9,
        },
    },
    ["Parry"] = {
        Duration = 1.0666666666666667, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["ParryStart"] = 0.22,
            ["ParryEnd"] = 0.39,
            ["RecoveryEnd"] = 1.05,
        },
    },
    ["Riposte"] = {
        Duration = 2.3, Loop = false,
        SuggestedTravel = 0.7,
        Markers = {
            ["Swing"] = 0.69,
            ["ActiveStart"] = 0.8,
            ["Impact"] = 0.96,
            ["ActiveEnd"] = 1.08,
            ["RecoveryEnd"] = 2.3,
        },
    },
    ["Hit_Front"] = {
        Duration = 0.8, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["Impact"] = 0,
            ["RecoveryEnd"] = 0.8,
        },
    },
    ["Hit_Back"] = {
        Duration = 0.8, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["Impact"] = 0,
            ["RecoveryEnd"] = 0.8,
        },
    },
    ["Hit_Left"] = {
        Duration = 0.8, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["Impact"] = 0,
            ["RecoveryEnd"] = 0.8,
        },
    },
    ["Hit_Right"] = {
        Duration = 0.8, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["Impact"] = 0,
            ["RecoveryEnd"] = 0.8,
        },
    },
    ["Dodge_Forward"] = {
        Duration = 0.9333333333333333, Loop = false,
        SuggestedTravel = 3.8,
        Markers = {
            ["DodgeStart"] = 0.13,
            ["DodgeEnd"] = 0.53,
            ["RecoveryEnd"] = 0.92,
        },
    },
    ["Dodge_Backward"] = {
        Duration = 0.9333333333333333, Loop = false,
        SuggestedTravel = 3.8,
        Markers = {
            ["DodgeStart"] = 0.13,
            ["DodgeEnd"] = 0.53,
            ["RecoveryEnd"] = 0.92,
        },
    },
    ["Dodge_Left"] = {
        Duration = 0.9333333333333333, Loop = false,
        SuggestedTravel = 3.8,
        Markers = {
            ["DodgeStart"] = 0.13,
            ["DodgeEnd"] = 0.53,
            ["RecoveryEnd"] = 0.92,
        },
    },
    ["Dodge_Right"] = {
        Duration = 0.9333333333333333, Loop = false,
        SuggestedTravel = 3.8,
        Markers = {
            ["DodgeStart"] = 0.13,
            ["DodgeEnd"] = 0.53,
            ["RecoveryEnd"] = 0.92,
        },
    },
    ["Jump"] = {
        Duration = 0.7333333333333333, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["Takeoff"] = 0.25,
        },
    },
    ["Fall"] = {
        Duration = 1.0, Loop = true,
        SuggestedTravel = 0,
        Markers = {
        },
    },
    ["Land"] = {
        Duration = 0.8333333333333334, Loop = false,
        SuggestedTravel = 0,
        Markers = {
            ["FootPlant"] = 0.06,
            ["RecoveryEnd"] = 0.83,
        },
    },
}
