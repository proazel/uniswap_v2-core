// SPDX-License-Identifier: MIT
pragma solidity >=0.5.16;


import './interfaces/IUniswapV2ERC20.sol';
import './libraries/SafeMath.sol';

// 컨트랙트 상속
contract UniswapV2ERC20 is IUniswapV2ERC20 {
    using SafeMath for uint; // 위에서 import하여 내부 라이브러리 add/sub/mul 사용

    // 변수 선언
    string public constant name = 'Uniswap V2 Project';
    string public constant symbol = 'UNI-V2';
    uint8 public constant decimals = 18;
    uint  public totalSupply;

    // mapping : 주소와 잔액을 연결하는 연결 배관
    // address : 주소형 키타입으로 unit을 타입으로 매핑 설정
    mapping(address => uint) public balanceOf; // 모든 잔액을 가진 배열
    mapping(address => mapping(address => uint)) public allowance;

    bytes32 public DOMAIN_SEPARATOR; // 가스 비용 때문에 바이트로 선언
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint) public nonces;

    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    /*
        constructor(생성자)
        클래스 내의 객체를 만들고 초기화하는데 도움이 되는 특수 함수로,
        상태변수 데이터를 초기화해주며, 최초 계약 배포 시점에 한해 1회만 수행 됨
    */
    // 컴파일 시 생성 되는 ABI의 정보를 다시 encode하고 해시로 감싼 다음,
    // 해당 값을 가져와서 초기화
    constructor() public {
        uint chainId;
        assembly {
            chainId := chainid // 초기화
        }
        DOMAIN_SEPARATOR = keccak256( // keccak256 해시를 계산하여 저장
            abi.encode(
                keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
                keccak256(bytes(name)),
                keccak256(bytes('1')),
                chainId,
                address(this) // 현재 컨트랙트의 address로 명시적 변환
            )
        );
    }

    // 토큰 발행
    function _mint(address to, uint value) internal {
        totalSupply = totalSupply.add(value);       // 발행
        balanceOf[to] = balanceOf[to].add(value);   // 저장
        emit Transfer(address(0), to, value);       // 코인 전송
        // to: 토큰 받을 주소, value: 받을 토큰의 양
    }

    // 토큰 소각
    function _burn(address from, uint value) internal {
        balanceOf[from] = balanceOf[from].sub(value);   // 발행과 반대로 마이너스 처리
        totalSupply = totalSupply.sub(value);           // add != sub
        emit Transfer(from, address(0), value);
    }

    // 승인
    function _approve(address owner, address spender, uint value) private {
        allowance[owner][spender] = value; // 송금액
        emit Approval(owner, spender, value);
    }

    // 전송, value 토큰이 from 계정에서 to 계정으로 이동 할 때 발생
    function _transfer(address from, address to, uint value) private {
        balanceOf[from] = balanceOf[from].sub(value);   // from 계정에서 보내는거니 뺴주고
        balanceOf[to] = balanceOf[to].add(value);       // to 계정에서 받아가는거라 더해줌
        emit Transfer(from, to, value);
    }

    // 다른 주소에서 토큰을 이체 할 수 있도록 하는 함수
    // spender: 지출 권한이 있는 주소, value: 지출 가능한 최대 금액
    function approve(address spender, uint value) external returns (bool) {
        // msg.sender = 현재 함수를 호출한 사람, 또는 스마트 컨트랙트의 주소
        // 개인 키 역할을 하기 때문에 보안성을 높일 수 있음
        _approve(msg.sender, spender, value);
        return true;
    }

    // _transfer 함수 호출, from을 msg.sender의 주소로 처리
    function transfer(address to, uint value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    // value값을 from이 to에게 전달
    function transferFrom(address from, address to, uint value) external returns (bool) {
        // 조건문 이해 못함, uint(-1)이 뭐지?
        if (allowance[from][msg.sender] != uint(-1)) {
            allowance[from][msg.sender] = allowance[from][msg.sender].sub(value);
        }
        _transfer(from, to, value);
        return true;
    }

    // 허용
    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external {
        // 'block.timestamp'('uint') : 유닉스 시대 이후의 현재 블록 타임 스탬프 (초)
        // deadline이 현재 block.timestamp보다 크거나 같으면,
        // == 현재 시간이 deadline 을 초과할 경우 -> 'UniswapV2: EXPIRED' 출력
        require(deadline >= block.timestamp, 'UniswapV2: EXPIRED');
        // 'UniswapV2: EXPIRED' = 메인넷에 boradcast 하는데 너무 오래걸리면 출력되는 결과
        // 스왑을 실행하는데 20분 넘게 걸리는 경우 코어 컨트랙트 허용 X
        bytes32 digest = keccak256(
            abi.encodePacked( // ncode 방식보다 간편한 인코딩을 위해 abi.encodepacked() 함수 사용
                '\x19\x01',
                DOMAIN_SEPARATOR,
                // keccak256으로 hashing 할 때 복수개의 인자를 전달하면, abi.encodepacked() 함수로 인코딩하여 해싱
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonces[owner]++, deadline))
            )
        );
        // 서명 된 메시지를 v/r/s로 분할 한 다음 원래 메시지와 함께 ecrecover를 수행
        // ecrecover를 사용하여 함수의 서명자를 검색
        address recoveredAddress = ecrecover(digest, v, r, s); // 서명 시 주소를 복구 할 때 사용
        // require 내용 : 유효하지 않은 서명은 빈 주소를 생성
        // 만족하면 _approve 함수 호출
        require(recoveredAddress != address(0) && recoveredAddress == owner, 'UniswapV2: INVALID_SIGNATURE');
        _approve(owner, spender, value);
    }
}