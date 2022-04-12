pragma solidity ^0.8.0;

/* This contract implements a factory contract that can be used by anyone to
 * create a new TicTakToe game. This contract keeps a mapping with all the
 * games including the state, address, and creator for each game.
 */
contract TicTakToeFactory {
    //enum for game state
    enum State {
        OPEN,
        ACTIVE,
        CLOSED
    }
    struct Game {
        address gameAddress;
        address creator;
        State gameState;
    }
    mapping(uint256 => Game) public directory;
    uint256 public numGames;

    //event emitted when new game is created
    event NewGame(
        address indexed creator,
        address indexed gameAddress,
        uint256 gameID
    );

    /* Function to create a new game, can be called by any external address, caller
     * must pass in the address of the player they wish to invite to the game.
     */
    function createGame(address _toChallenge) external {
        require(msg.sender != _toChallenge, "You cannot challenge yourself");

        //deploy new game contract
        address createdAddress = address(
            new TicTakToeGame(msg.sender, _toChallenge, numGames)
        );

        //store new game in mapping with game address, creator, and initial state
        directory[numGames] = Game(createdAddress, msg.sender, State.OPEN);
        numGames++;

        emit NewGame(msg.sender, createdAddress, numGames - 1);
    }

    /* Function to update the state of a game within the mapping. This function
     * can only be invoked by the game contract itself.
     */
    function setGameState(uint256 _gameID, State _newState) external {
        require(
            msg.sender == directory[_gameID].gameAddress,
            "Only game itself can update its state"
        );

        directory[_gameID].gameState = _newState;
    }
}

/* This contract implements the TicTakToe game itself. It contains external functions
 * to change the invite address, accept an invitation to the game, and to perform
 * a move on the TicTakToe board.
 */
contract TicTakToeGame {
    //game ID
    uint256 public immutable ID;
    //address of factory contract
    address public immutable FACTORY;

    //enum for game state
    enum State {
        OPEN,
        ACTIVE,
        CLOSED
    }
    State public state;

    address public creator;
    address public invited;

    address public player1;
    address public player2;

    //TicTakToe board - 0 for open square, 1 for "O", 2 for "X"
    uint8[3][3] board;

    /* Mapping representing win states - the TikTakToe game has 8 possible win
     * states, every time an "O" is added to a possible win state, add 1 to the
     * win state ID in the mapping and every time an "X" is added to a possible
     * win state, subtract 1 from the win state ID in the mapping.
     */
    mapping(uint8 => int8) winStates;

    uint8 public moveCount;
    address public winner;

    //event emitted when address is invited to the game
    event Invite(address indexed challenger, address indexed invited);

    //event emitted when player accepts invite to the game
    event InviteAccepted(address indexed invited);

    //event emitted to indicate a move made in the game
    event Move(
        address indexed player,
        uint8 indexed move,
        uint8 row,
        uint8 col
    );

    //event emitted when player has won the game
    event Win(address indexed winner, uint8 move);

    //event emitted when the game ends in a draw
    event Draw();

    //constructor takes in the challenger, invited address, and game ID
    constructor(
        address _challenger,
        address _invited,
        uint256 _gameID
    ) {
        ID = _gameID;
        FACTORY = msg.sender;

        creator = _challenger;
        invited = _invited;
        state = State.OPEN;

        emit Invite(_challenger, _invited);
    }

    //modifier to ensure game is in Active state
    modifier isActive() {
        require(
            state == State.ACTIVE,
            "Game must be active to perform this action"
        );
        _;
    }

    //modifier to ensure game is in Open state
    modifier isOpen() {
        require(
            state == State.OPEN,
            "Game must be open to perform this action"
        );
        _;
    }

    /* Function to change the invite address. This can only be done when the game
     * state is open meaning that no one has accepted the invitation yet. Only
     * the creator of the game can change the invited address.
     */
    function changeInvite(address _newInvited) external isOpen {
        require(
            msg.sender == creator,
            "Only creator can change invite address"
        );
        require(invited != _newInvited, "Player has already been invited");

        invited = _newInvited;

        emit Invite(msg.sender, _newInvited);
    }

    /* Function to accept an invitation to the game. This function can only be
     * invoked when the game is still open. Additionally, only the invited address
     * can accept the game invitation.
     */
    function acceptInvite() external isOpen {
        require(
            msg.sender == invited,
            "You have not been invited to join this game"
        );

        //compute the hash of the concatenated player addresses and cast to uint256
        uint256 hashed = uint256(
            keccak256(abi.encodePacked(creator, msg.sender))
        );

        //get first bit of the hash
        hashed = hashed >> 255;

        //if first bit is 0, creator is "O" and invited is "X", and vice versa
        if (hashed == 0) {
            player1 = creator;
            player2 = invited;
        } else {
            player1 = invited;
            player2 = creator;
        }

        //set game state to active in this contract and in Factory contract
        state = State.ACTIVE;
        TicTakToeFactory(FACTORY).setGameState(
            ID,
            TicTakToeFactory.State.ACTIVE
        );

        emit InviteAccepted(invited);
    }

    /* Function representing a move in the TicTakToe game. This function can only
     * be invoked by a valid player of the game while the game is in the Active
     * state. At the end of every move, this function checks for either a winner
     * or a draw.
     */
    function move(uint8 row, uint8 col) external isActive {
        require(
            msg.sender == creator || msg.sender == invited,
            "Invalid player"
        );
        require(row <= 2 && col <= 2, "Invalid position");
        require(board[row][col] == 0, "Position not empty");

        //player 1 plays "O"
        if (msg.sender == player1) {
            //player 1 goes second (moveCount must be odd because it starts at 0)
            require(moveCount % 2 != 0, "Not your turn");

            //"O" is represented by 1
            board[row][col] = 1;

            //update row and column win states (increment for "O")
            winStates[row]++;
            winStates[col + 3]++;

            //update diagonal win states if they apply
            if (row == col) {
                winStates[6]++;
            }
            if (
                (row == 0 && col == 2) ||
                (row == 1 && col == 1) ||
                (row == 2 && col == 0)
            ) {
                winStates[7]++;
            }
        } else {
            //player 2 goes first (moveCount must be even because it starts at 0)
            require(moveCount % 2 == 0, "Not your turn");

            //"X" is represented by 2
            board[row][col] = 2;

            //update row and column win states (decrement for "X")
            winStates[row]--;
            winStates[col + 3]--;

            //update diagonal win states if they apply
            if (row == col) {
                winStates[6]--;
            }
            if (
                (row == 0 && col == 2) ||
                (row == 1 && col == 1) ||
                (row == 2 && col == 0)
            ) {
                winStates[7]--;
            }
        }

        moveCount++;

        //check if this move is a winning move
        bool winningMove = _isWinningMove();

        //if this move is a winning move
        if (winningMove) {
            winner = msg.sender;

            //set game state to Closed in this contract and in Factory contract
            state = State.CLOSED;
            TicTakToeFactory(FACTORY).setGameState(
                ID,
                TicTakToeFactory.State.CLOSED
            );
            //if it is not a winning move, but 9 moves have been made, it is a draw
        } else if (moveCount == 9) {
            //set game state to Closed in this contract and in Factory contract
            state = State.CLOSED;
            TicTakToeFactory(FACTORY).setGameState(
                ID,
                TicTakToeFactory.State.CLOSED
            );
        }

        emit Move(msg.sender, moveCount, row, col);

        //conditionally emit Win and Draw events
        if (winningMove) {
            emit Win(msg.sender, moveCount);
        } else if (moveCount == 9) {
            emit Draw();
        }
    }

    /* Internal function to determine whether or not a move is a winning move.
     * Function checks all 8 win states and returns true if any have a value of
     * 3 (player 1 wins) or -3 (player 2 wins).
     */
    function _isWinningMove() internal view returns (bool) {
        //iterate through all 8 win states
        for (uint8 i; i < 8; i++) {
            if (winStates[i] == 3 || winStates[i] == -3) {
                return true;
            }
        }
        return false;
    }
}
