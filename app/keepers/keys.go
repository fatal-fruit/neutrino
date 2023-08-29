package keepers

import (
	storetypes "cosmossdk.io/store/types"
	upgradetypes "cosmossdk.io/x/upgrade/types"
	authtypes "github.com/cosmos/cosmos-sdk/x/auth/types"
	banktypes "github.com/cosmos/cosmos-sdk/x/bank/types"
	consensusparamtypes "github.com/cosmos/cosmos-sdk/x/consensus/types"
	distrtypes "github.com/cosmos/cosmos-sdk/x/distribution/types"
	govtypes "github.com/cosmos/cosmos-sdk/x/gov/types"
	paramstypes "github.com/cosmos/cosmos-sdk/x/params/types"
	stakingtypes "github.com/cosmos/cosmos-sdk/x/staking/types"
	//capabilitytypes "github.com/cosmos/ibc-go/modules/capability/types"
	// IBC Imports
	//capabilitytypes "github.com/cosmos/ibc-go/modules/capability/types"
	//ibctransfertypes "github.com/cosmos/ibc-go/v7/modules/apps/transfer/types"
	//ibcexported "github.com/cosmos/ibc-go/v7/modules/core/exported"
)

func (appKeepers *AppKeepers) GenerateKeys() {
	appKeepers.keys = storetypes.NewKVStoreKeys(
		authtypes.StoreKey,
		banktypes.StoreKey,
		stakingtypes.StoreKey,
		//ibcexported.StoreKey,
		//ibctransfertypes.StoreKey,
		distrtypes.StoreKey,
		govtypes.StoreKey,
		paramstypes.StoreKey,
		//capabilitytypes.StoreKey,
		consensusparamtypes.StoreKey,
		upgradetypes.StoreKey,
		// TODO: Add store key
	)

	appKeepers.tkeys = storetypes.NewTransientStoreKeys(paramstypes.TStoreKey)
	appKeepers.memKeys = storetypes.NewMemoryStoreKeys()
	//appKeepers.memKeys = storetypes.NewMemoryStoreKeys(capabilitytypes.MemStoreKey)
}

func (appKeepers *AppKeepers) GetKVStoreKeys() map[string]*storetypes.KVStoreKey {
	return appKeepers.keys
}

func (appKeepers *AppKeepers) GetTransientStoreKey() map[string]*storetypes.TransientStoreKey {
	return appKeepers.tkeys
}

func (appKeepers *AppKeepers) GetMemoryStoreKey() map[string]*storetypes.MemoryStoreKey {
	return appKeepers.memKeys
}

func (appKeepers *AppKeepers) GetKey(storeKey string) *storetypes.KVStoreKey {
	return appKeepers.keys[storeKey]
}

func (appKeepers *AppKeepers) GetTKey(storeKey string) *storetypes.TransientStoreKey {
	return appKeepers.tkeys[storeKey]
}

func (appKeepers *AppKeepers) GetMemKey(storeKey string) *storetypes.MemoryStoreKey {
	return appKeepers.memKeys[storeKey]
}
