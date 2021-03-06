## Usage

### Joining a game

- Connect a Socket to `ws://localhost:4000/socket/websocket`
- Topics recognized are `game:<name>` (e.g., `game:foo`)
- Joining will succeed or fail based on whether there is space in the game
  ```json
  { "payload": { "nickname": "name", "sign": "X" } }
  ```
- On success,
  ```json
  { "playing_as": "X" }
  ```
  will be returned.
- Game will be started if it does not exist and stopped when the last player leaves

### Playing the game

#### `play`

When you have joined a game topic, you can now send messages to play.

**Expected payload**:

```json
{ "x": 0, "y": 1 }
```

Coordinates of the field you would like to play, `(0,0)` is the bottom left, `(2,2)` is the top right of the board
The server will validate whether it's your turn and respond with success or error.

The outcome of your turn is then broadcasted in another message.

### Game events

These are broadcasted whenever something happens in the game.

#### `game_start`

Indicates that the game is full and players can now make moves -- they are not allowed beforehand.

**Payload**:

- `current_player`: Who's turn it is ("X" or "O").
- `board`: Serialized version of the game board, e.g.:
  ```json
  { "top": ["", "X", "O"], "middle": ["", "", ""], "bottom": ["O", "X", ""] }
  ```
- `joined_players`: List of pairs of player's sign and player's nickname, e.g.:
  ```json
  {"X": "first_player_name", "O": "second_player_name" }
  ```

#### `game_update`

Indicates that one of players made a move.

**Payload**: Same as `game_start` without `joined_players`, and also

```json
{ "move": [0, 1] }
```

#### `game_end`

Indicates that the game is full and players can now make moves -- they are not allowed beforehand.

**Payload**:

- `outcome`: Why the game ended ("Draw", "X wins", "O wins")
- `board`: Serialized version of the game board, e.g.:
  ```json
  { "top": ["", "X", "O"], "middle": ["", "", ""], "bottom": ["O", "X", ""] }
  ```

#### `player_left`

Indicates that a player left the game (e.g., by closing the browser tab).

**Payload**: none

#### `reset`

Indicates that one of the player made reset of board,

**Payload**:

- `current_player`: Who's turn it is ("X" or "O").
- `board`: Serialized version of the game board, e.g.:
  ```json
  { "top": ["", "X", "O"], "middle": ["", "", ""], "bottom": ["O", "X", ""] }
  ```
- `joined_players`: List of pairs of player's sign and player's nickname, e.g.:
  ```json
  {"X": "first_player_name", "O": "second_player_name" }
  ```


### Rooms rest API


 - GET     /room - get list of rooms
 - POST    /room - create room with name passed in json example ex. `{"name": "foo"}`
 - GET     /room/:id - get name of room by id  
 - DELETE  /room/:id - delete room by id
