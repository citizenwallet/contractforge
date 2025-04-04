// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../../src/utils/SafeSuiteLib.sol";
import "./SafeBytecode.sol";

contract SafeDeployer {
    address public constant SAFE_SINGLETON_ADDRESS = 0x41675C099F32341bf84BFc5382aF534df5C7461a;

	/**
	 * @dev deploy the Simulate Tx Accesor
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0x3d4BA2E0884aa488718476ca2FB8Efc291A46199,
	 * according to safe-global/safe-deployments/src/assets/v1.4.0/simulate_tx_accessor.json
	 */
	function deploySimulateTxAccessor() public {
		// deployment code extracted from production contract
		bytes
			memory code = hex"60a060405234801561001057600080fd5b503073ffffffffffffffffffffffffffffffffffffffff1660808173ffffffffffffffffffffffffffffffffffffffff1660601b8152505060805160601c6103526100656000398061017052506103526000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c80631c5fb21114610030575b600080fd5b6100de6004803603608081101561004657600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190803590602001909291908035906020019064010000000081111561008d57600080fd5b82018360208201111561009f57600080fd5b803590602001918460018302840111640100000000831117156100c157600080fd5b9091929391929390803560ff169060200190929190505050610169565b60405180848152602001831515815260200180602001828103825283818151815260200191508051906020019080838360005b8381101561012c578082015181840152602081019050610111565b50505050905090810190601f1680156101595780820380516001836020036101000a031916815260200191505b5094505050505060405180910390f35b60008060607f000000000000000000000000000000000000000000000000000000000000000073ffffffffffffffffffffffffffffffffffffffff163073ffffffffffffffffffffffffffffffffffffffff161415610213576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260398152602001806102e46039913960400191505060405180910390fd5b60005a9050610269898989898080601f016020809104026020016040519081016040528093929190818152602001838380828437600081840152601f19601f82011690508083019250505050505050885a610297565b92505a8103935060405160203d0181016040523d81523d6000602083013e8092505050955095509592505050565b60006001808111156102a557fe5b8360018111156102b157fe5b14156102ca576000808551602087018986f490506102da565b600080855160208701888a87f190505b9594505050505056fe53696d756c61746554784163636573736f722073686f756c64206f6e6c792062652063616c6c6564207669612064656c656761746563616c6ca264697066735822122066ec514c62d72e456c1ac0997627506854acd03fceabe3c0532054bd50122c9064736f6c63430007060033";

		deployContractFromSingletonDefault(SafeSuiteLib.SAFE_SimulateTxAccessor_ADDRESS, code);
	}

    // ... [Include all other deployment functions from the original contract]

    /**
     * @dev deploy an arbitrary contract from the Singleton contract
     * without providing the salt, it gets defaut to 0x
     */
    function deployContractFromSingletonDefault(address expectedAddress, bytes memory contractDeploymentCode) internal {
        // check if contract has been deployed
        if (isContract(expectedAddress)) {
            return;
        }
        // build the deployment code for the proxy
        bytes memory deploymentCode = abi.encodePacked(bytes32(0x00), contractDeploymentCode);
        // deploy Safe proxy from the Singleton
        (bool successDeploySafeProxyFactory, ) = SAFE_SINGLETON_ADDRESS.call(deploymentCode);
        if (!successDeploySafeProxyFactory) {
            console.log("Cannot deploy safe proxy factory");
        }
    }

    /**
     * @dev Check if an address is a contract
     */
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
} 