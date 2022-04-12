pragma solidity ^0.8.0;

contract TicTakToeFactory {
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

    event NewGame(
        address indexed creator,
        address indexed gameAddress,
        uint256 gameID
    );

    function createGame(address _toChallenge) external {
        require(msg.sender != _toChallenge, "You cannot challenge yourself");
        address createdAddress = address(
            new TicTakToeGame(msg.sender, _toChallenge, numGames)
        );
        directory[numGames] = Game(createdAddress, msg.sender, State.OPEN);
        numGames++;

        emit NewGame(msg.sender, createdAddress, numGames - 1);
    }

    function setGameState(uint256 _gameID, State _newState) external {
        require(
            msg.sender == directory[_gameID].gameAddress,
            "Only game itself can update its state"
        );

        directory[_gameID].gameState = _newState;
    }
}

contract TicTakToeGame {
    uint256 public immutable ID;
    address public immutable FACTORY;
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

    //0 for open square, 1 for "O", 2 for "X"
    uint256[3][3] board;
    mapping(uint256 => int256) winStates;
    uint8 public moveCount;
    address public winner;

    event Invite(address indexed challenger, address indexed invited);
    event InviteAccepted(address indexed invited);
    event Move(
        address indexed player,
        uint256 indexed move,
        uint256 row,
        uint256 col
    );
    event Win(address indexed winner, uint256 move);
    event Draw();

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

    modifier isActive() {
        require(
            state == State.ACTIVE,
            "Game must be active to perform this action"
        );
        _;
    }

    modifier isOpen() {
        require(
            state == State.OPEN,
            "Game must be open to perform this action"
        );
        _;
    }

    function changeInvite(address _newInvited) external isOpen {
        require(
            msg.sender == creator,
            "Only creator can change invite address"
        );
        require(invited != _newInvited, "Player has already been invited");

        invited = _newInvited;

        emit Invite(msg.sender, _newInvited);
    }

    function acceptInvite() external isOpen {
        require(
            msg.sender == invited,
            "You have not been invited to join this game"
        );

        uint256 hashed = uint256(
            keccak256(abi.encodePacked(creator, msg.sender))
        );
        hashed = hashed >> 255;
        if (hashed == 0) {
            player1 = creator;
            player2 = invited;
        } else {
            player1 = invited;
            player2 = creator;
        }

        state = State.ACTIVE;
        TicTakToeFactory(FACTORY).setGameState(
            ID,
            TicTakToeFactory.State.ACTIVE
        );

        emit InviteAccepted(invited);
    }

    function move(uint256 row, uint256 col) external isActive {
        require(
            msg.sender == creator || msg.sender == invited,
            "Invalid player"
        );
        require(row <= 2 && col <= 2, "Invalid position");
        require(board[row][col] == 0, "Position not empty");

        if (msg.sender == player1) {
            require(moveCount % 2 != 0, "Not your turn");

            board[row][col] = 1;
            winStates[row]++;
            winStates[col + 3]++;
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
            require(moveCount % 2 == 0, "Not your turn");

            board[row][col] = 2;
            winStates[row]--;
            winStates[col + 3]--;
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
        bool winningMove = _isWinningMove();

        if (winningMove) {
            winner = msg.sender;
            state = State.CLOSED;
            TicTakToeFactory(FACTORY).setGameState(
                ID,
                TicTakToeFactory.State.CLOSED
            );
        } else if (moveCount == 9) {
            state = State.CLOSED;
            TicTakToeFactory(FACTORY).setGameState(
                ID,
                TicTakToeFactory.State.CLOSED
            );
        }

        emit Move(msg.sender, moveCount, row, col);

        if (winningMove) {
            emit Win(msg.sender, moveCount);
        } else if (moveCount == 9) {
            emit Draw();
        }
    }

    function _isWinningMove() internal view returns (bool) {
        for (uint256 i; i < 8; i++) {
            if (winStates[i] == 3 || winStates[i] == -3) {
                return true;
            }
        }
        return false;
    }
}
