pragma solidity ^0.4.9;

contract Contract {
  //Deployer of the game contract
  address public creator;
  //Minimum amount of ether required to participate
  uint public threshold;
  //Latest blockstamp, used to set time limit for players
  uint private lastUpdate;

  //Console logs event when move is made
  event madeMove(bytes32 prefix, uint8 rowNum, bytes8 column, uint8 col);

  event row_1(uint8[3] row1);
  event row_2(uint8[3] row2);
  event row_3(uint8[3] row3);

  event Won(bytes12 player);

  event kickedout(address player);

  //A complex type that represents a player
  struct Player {
    address playerAddress;
    uint paid;
    uint payback;
  }

  struct Underdog {
    address returnAddress;
    uint amount;
  }

  /*Accounts that have paid >= threshold
   that are able to participate in the game*/
  mapping(uint8=>Player) private players;

  uint8 private num_of_players = 0;

  /*Accounts that have paid < threshold, cannot
  participate in the game but funds will be returned
  when the game ends.*/
  mapping (uint8=>Underdog) private underdogs;

  uint8 private num_of_underdogs;

  modifier hasValue {
    if (msg.value > 0) {
      _;
    } else {
      throw;
    }
  }

  modifier onlyCreator {
    if (msg.sender != creator) {
      throw;
    } else {
      _;
    }
  }
  
  function payeeState() constant returns (uint8[2]) {
      return [uint8(players[1].paid), uint8(players[1].payback)];
  }
  
  function challengerState() constant returns (uint8[2]) {
      return [uint8(players[2].paid), uint8(players[2].payback)];
  }

  function payeeAddress() constant returns (address) {
    return players[1].playerAddress;
  }

  function challengerAddress() constant returns (address) {
    return players[2].playerAddress;
  }

  /*function print_board() constant returns (string) {
    bytes memory bytesRow = new bytes(32);
    //row1
    bytesRow[0] = bytes1(board[0][0]);
    bytesRow[1] = "|";
    bytesRow[2] = bytes1(board[0][1]);
    bytesRow[3] = "|";
    bytesRow[4] = bytes1(board[0][2]);
    bytesRow[5] = "\n";
    //row2
    bytesRow[6] = bytes1(board[1][0]);
    bytesRow[7] = "|";
    bytesRow[8] = bytes1(board[1][1]);
    bytesRow[9] = "|";
    bytesRow[10] = bytes1(board[1][2]);
    bytesRow[11] = "\n";
    //row3
    bytesRow[12] = bytes1(board[2][0]);
    bytesRow[13] = "|";
    bytesRow[14] = bytes1(board[2][1]);
    bytesRow[15] = "|";
    bytesRow[16] = bytes1(board[2][2]);
    bytesRow[17] = "\n";
    return string(bytesRow);
  } */
  
  /** Setting Up Game*/
  function Contract() {
    creator = msg.sender;
    //threshold = _amount * uint(11) / uint(10);
    players[1] = Player({
      playerAddress: msg.sender,
      paid: 0,
      payback: 0
    });
    num_of_players += 1;
    lastUpdate = now;
  }

  bool private creatorPaid = false;

  modifier gameCanBegin {
    if (!creatorPaid) {
      throw;
    } else {
      _;
    }
  }

  function creatorPay() payable onlyCreator hasValue {
    if (creatorPaid) {
      throw;
    } else {
      players[1].paid = msg.value;
      threshold = msg.value * uint(11) / uint(10);
      creatorPaid = true;
    }
  }
  
  /** Challenger joins. */
  function challengerJoin() public payable hasValue gameCanBegin {
    if (num_of_players == 2 && now - lastUpdate > 1 hours + 15 minutes) {
      if (turn == 1) {
        reset(2);
      } else {
        reset(1);
      }
    } else if (num_of_players == 2) {
      throw;
    }
    if (msg.value < threshold) {
      underdogs[num_of_underdogs] = Underdog({
        returnAddress: msg.sender,
        amount: msg.value
      });
      num_of_underdogs += 1;
    } else {
      players[2] = Player({
        playerAddress: msg.sender,
        paid: msg.value,
        payback: 0
      });
      lastUpdate = now;
      num_of_players += 1;
    }
  }

  /** Game Part */
  //Virtual representation of the game board
  uint8[3][3] private board = [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
  //Determine player's turn: 1 is payee, 2 is challenger
  uint8 private turn = 1;
  //Token of winner
  uint8 private winner = 0;

  function makeMove(uint8 _row, uint8 _col) public {
    if (_row > 3 || _col > 3 || players[turn].playerAddress != msg.sender
      || board[_row - 1][_col - 1] != 0 || num_of_players != 2) {
      throw;
    } else {
      board[_row - 1][_col - 1] = turn;
      lastUpdate = now;
      if (turn == 1) {
          madeMove("Payee--row: ", _row, "column: ", _col);
      } else {
          madeMove("Challenger--row: ", _row, "column: ", _col);
      }
      row_1(board[0]);
      row_2(board[1]);
      row_3(board[2]);
      bool gameOver = true;
      for (uint8 i = 0; i < 3; i++) {
        for (uint8 j = 0; j < 3; j++) {
          if (board[i][j] == 0) {
            gameOver = false;
          }
        }
      }
      checkWinner();
      if (gameOver) {
        reset(2);
      }
      changeTurn();
    }
  }

  function checkWinner() private {
    winner = checkBoard();
    if (winner != 0) {
      reset(winner);
      if (winner == 1) {
        Won("Payee");
      } else {
        Won("Challenger");
      }
    }
  }

  event sentMoney(address player, uint amount);

  function withdraw() public {
    if (msg.sender == players[1].playerAddress) {
      reset(2);
    } else if (msg.sender == players[2].playerAddress) {
      reset(1);
    } else {
      for (uint8 i = 0; i < num_of_underdogs; i += 1) {
        if (underdogs[i].returnAddress == msg.sender) {
          sendMoney(msg.sender, underdogs[i].amount);
        }
      }
    }
  }

  function sendMoney(address _recipient, uint _amount) private {
    if (!_recipient.send(_amount)) {
      for (uint8 i = 0; i < num_of_underdogs; i += 1) {
        if (underdogs[i].returnAddress == _recipient) {
          throw;
        }
      }
      underdogs[num_of_underdogs] = Underdog({
        returnAddress: _recipient,
        amount: _amount
      });
      throw;
    } else {
      for (uint8 j = 0; j < num_of_underdogs; j += 1) {
        if (underdogs[j].returnAddress == _recipient) {
          delete underdogs[j];
        }
      }
      sentMoney(_recipient, _amount);
    }
  }

  /** Create a copy of a player*/
  function copyPlayer(uint8 token) private returns (Player) {
    return Player({
      playerAddress: players[token].playerAddress,
      paid: players[token].paid,
      payback: players[token].payback
    });
  }


  /** Resets game depending on who wins*/
  function reset(uint8 winner) private {
    //If payee wins
    if (winner == 1) {
      players[1].payback = players[2].paid - players[1].paid + players[1].paid;
      sendMoney(players[1].playerAddress, players[1].payback);
    } else {  //if challenger wins
      sendMoney(players[1].playerAddress, players[1].paid);
      threshold = players[2].paid;
    }
    players[1] = copyPlayer(2);
    delete players[2];
    resetBoard();
    num_of_players -= 1;
  }

  function resetBoard() private {
    for (uint i = 0; i < board.length; i++) {
      board[i][0] = 0;
      board[i][1] = 0;
      board[i][2] = 0;
    }
  }

  /** Modify uint8 turn */
  function changeTurn() private {
    if (turn == 1) {
      turn = 2;
    } else {
      turn = 1;
    }
  }

  //Check all possible ways of winning and return 0, 1, 2 depending on situations
  function checkBoard() private returns (uint8) {
    checkRows();
    checkColumns();
    checkDiags();
    return winner;
  }

  /** Check rows and return winner's token if any, otherwise 0*/
  function checkRows() private {
    for (uint i = 0; i < board.length; i++) {
      if (board[i][0] != 0 && board[i][0] == board[i][1] && board[i][0] == board[i][2]) {
        winner = board[i][0];
      }
    }
  }

  /** Check columns and return winner's token if any, otherwise 0*/
  function checkColumns() private {
    for (uint i = 0; i < board[0].length; i++) {
      if (board[0][i] != 0 && board[0][i] == board[1][i] &&  board[0][i] == board[2][i]) {
        winner = board[0][i];
      }
    }
  }

  /** Check diagonals and return winner's token if any, otherwise 0*/
  function checkDiags() private {
    if (board[1][1] != 0 && board[1][1] == board[0][0] && board[1][1] == board[2][2] || board[1][1] != 0 && board[1][1] == board[0][2] && board[1][1] == board[2][0]) {
      winner = board[1][1];
    }
  }

  /** Clear the contract */
  function kill() onlyCreator {
    if (msg.gas < 500 * (num_of_underdogs + num_of_players)) {
      throw;
    }
    for (uint8 i = 0; i < num_of_underdogs; i++) {
      sendMoney(underdogs[i].returnAddress, underdogs[i].amount);
    }
    sendMoney(players[1].playerAddress, players[1].paid);
    sendMoney(players[2].playerAddress, players[2].paid);
    suicide(creator);
  }
}
