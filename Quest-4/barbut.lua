-- barbut_single.lua
-- GLOBAL VARIABLES

-- Game progression modes
GameMode = GameMode or "Not-Started"
StateChangeTime = StateChangeTime or nil

-- State durations (in milliseconds)
WAIT_TIME = 1 * 60 * 500 -- 1 minute
NOW = NOW or nil         -- Current time, updated on every message

-- Players waiting to join the next game and their payment status
Players = Players or {}
-- Active game status
ActiveGame = ActiveGame or false
-- Listeners for game events
Listeners = Listeners or {}

-- Sends a state change announcement to all registered listeners.
function announce(event, description)
    for _, address in pairs(Listeners) do
        ao.send({
            Target = address,
            Action = "Announcement",
            Event = event,
            Data = description
        })
    end
    return print("Announcement: " .. event .. " " .. description)
end

-- Rolls a dice and returns a number between 1 and 6.
function rollDice()
    return math.random(1, 6)
end

-- Starts the waiting period for players to become ready to play.
function startWaitingPeriod()
    GameMode = "Waiting"
    StateChangeTime = NOW + WAIT_TIME
    announce("Started-Waiting-Period", "The game is about to begin!")
    print('Starting Waiting Period')
end

-- Starts the game
function startGamePeriod()
    if #Players == 0 then
        announce("No-Player", "No players registered! Restarting...")
        startWaitingPeriod()
        return
    end

    GameMode = "Playing"
    announce("Game-Started", "The game has started. Players can now roll dice with the 'Play' command.")
end

-- Processes a player's roll
function playGame(player)
    if GameMode ~= "Playing" then
        announce("Game-Not-Started", "Game has not started yet!")
        return
    end

    local dice1 = rollDice()
    local dice2 = rollDice()
    local sum = dice1 + dice2

    -- Determine initial roll outcome
    if sum == 7 or sum == 11 then
        announce("Game-Ended", "Congratulations! " .. player .. " wins with a roll of " .. sum .. ".")
    elseif sum == 2 or sum == 3 or sum == 12 then
        announce("Game-Ended", "Sorry, " .. player .. ". You lose with a roll of " .. sum .. ".")
    else
        -- Set point and continue rolling
        local point = sum
        announce("Point-Set", "Point is set to " .. point .. ". Continue rolling.")
        while true do
            dice1 = rollDice()
            dice2 = rollDice()
            sum = dice1 + dice2
            if sum == point then
                announce("Game-Ended", "Congratulations! " .. player .. " wins by hitting the point " .. sum .. ".")
                break
            elseif sum == 7 then
                announce("Game-Ended", "Sorry, " .. player .. ". You lose with a roll of " .. sum .. ".")
                break
            end
        end
    end

    ActiveGame = false
    startWaitingPeriod()
end

-- HANDLERS: Game state management

-- Handler for cron messages, manages game state transitions.
Handlers.add(
    "Game-State-Timers",
    function(Msg)
        return "continue"
    end,
    function(Msg)
        NOW = Msg.Timestamp
        if GameMode == "Not-Started" then
            startWaitingPeriod()
        elseif GameMode == "Waiting" then
            if NOW > StateChangeTime then
                startGamePeriod()
            end
        end
    end
)

-- Handler for player registrations to participate in the game.


Handlers.add(
    "Register",
    Handlers.utils.hasMatchingTag("Action", "Register"),
    function(Msg)
        table.insert(Players, Msg.From)
        ao.send({
            Target = Msg.From,
            Action = "Player-Registered"
        })
        print("Player registered: " .. Msg.From)

        -- Check if we can start the game after registration
        if #Players > 0 and GameMode == "Waiting" then
            startGamePeriod()
        end
    end
)

-- Handler for showing the number of registered players.
Handlers.add(
    "ShowPlayers",
    Handlers.utils.hasMatchingTag("Action", "ShowPlayers"),
    function(Msg)
        local count = #Players
        -- ao.send({
        --     Target = Msg.From,
        --     Action = "ShowPlayers",
        --     Data = "Number of registered players: " .. count
        -- })
        print("Number of registered players: " .. count)
    end
)

-- Handler for playing the game.
Handlers.add(
    "Play",
    Handlers.utils.hasMatchingTag("Action", "Play"),
    function(Msg)
        print("Play command received from: " .. Msg.From)
        playGame(Msg.From)
    end
)

-- Registers new listeners for the game and subscribes them for event info.
Handlers.add(
    "AddListener",
    Handlers.utils.hasMatchingTag("Action", "AddListener"),
    function(Msg)
        removeListener(Msg.From)
        table.insert(Listeners, Msg.From)
        ao.send({
            Target = Msg.From,
            Action = "Registered"
        })
        announce("New Listener Registered", Msg.From .. " has joined as a listener.")
    end
)

-- Unregisters listeners and stops sending them event info.
Handlers.add(
    "RemoveListener",
    Handlers.utils.hasMatchingTag("Action", "RemoveListener"),
    function(Msg)
        removeListener(Msg.From)
        ao.send({
            Target = Msg.From,
            Action = "Unregistered Listener"
        })

        announce("Listener UnRegistered", Msg.From .. " has unregistered as a listener.")
    end
)

-- Retrieves the current game state.
Handlers.add(
    "GetGameState",
    Handlers.utils.hasMatchingTag("Action", "GetGameState"),
    function(Msg)
        ao.send({
            Target = Msg.From,
            Action = "GameState",
            State = {
                GameMode = GameMode,
                ActiveGame = ActiveGame,
                RegisteredPlayers = #Players
            }
        })
    end
)

-- Helper function to remove listeners
function removeListener(listener)
    for i, v in ipairs(Listeners) do
        if v == listener then
            table.remove(Listeners, i)
            break
        end
    end
end
