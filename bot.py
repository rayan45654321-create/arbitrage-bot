from web3 import Web3
from web3.middleware import ExtraDataToPOAMiddleware
import time, sys, os

RPC_URL = os.environ.get("RPC_URL")
PRIVATE_KEY = os.environ.get("PRIVATE_KEY")
WALLET = "0x03f9097e1c2f21efc5c9aa5bce20435b18fccfb7"

WETH = "0x4200000000000000000000000000000000000006"
USDC = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"
AERO_ROUTER = "0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43"
AERO_FACTORY = "0x420DD381b31aEf6683db6B902084cB0FFECe40Da"
UNI_FACTORY = "0x33128a8fC17869897dcE68Ed026d694621f6FDfD"
MIN_PROFIT = 20.0

AERO_ABI = [{"inputs":[{"internalType":"uint256","name":"amountIn","type":"uint256"},{"components":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"bool","name":"stable","type":"bool"},{"internalType":"address","name":"factory","type":"address"}],"internalType":"struct IRouter.Route[]","name":"routes","type":"tuple[]"}],"name":"getAmountsOut","outputs":[{"internalType":"uint256[]","name":"amounts","type":"uint256[]"}],"stateMutability":"view","type":"function"}]
UNI_FACTORY_ABI = [{"inputs":[{"internalType":"address","name":"tokenA","type":"address"},{"internalType":"address","name":"tokenB","type":"address"},{"internalType":"uint24","name":"fee","type":"uint24"}],"name":"getPool","outputs":[{"internalType":"address","name":"pool","type":"address"}],"stateMutability":"view","type":"function"}]
POOL_ABI = [{"inputs":[],"name":"slot0","outputs":[{"internalType":"uint160","name":"sqrtPriceX96","type":"uint160"},{"internalType":"int24","name":"tick","type":"int24"},{"internalType":"uint16","name":"observationIndex","type":"uint16"},{"internalType":"uint16","name":"observationCardinality","type":"uint16"},{"internalType":"uint16","name":"observationCardinalityNext","type":"uint16"},{"internalType":"uint8","name":"feeProtocol","type":"uint8"},{"internalType":"bool","name":"unlocked","type":"bool"}],"stateMutability":"view","type":"function"}]

w3 = Web3(Web3.HTTPProvider(RPC_URL))
w3.middleware_onion.inject(ExtraDataToPOAMiddleware, layer=0)
print("Connected:", w3.is_connected())
print("Block:", w3.eth.block_number)

def get_uni_price():
    try:
        factory = w3.eth.contract(address=Web3.to_checksum_address(UNI_FACTORY), abi=UNI_FACTORY_ABI)
        pool_addr = factory.functions.getPool(
            Web3.to_checksum_address(WETH),
            Web3.to_checksum_address(USDC),
            500
        ).call()
        if pool_addr == "0x0000000000000000000000000000000000000000":
            return None
        pool = w3.eth.contract(address=pool_addr, abi=POOL_ABI)
        slot0 = pool.functions.slot0().call()
        sqrt_p = slot0[0]
        if sqrt_p == 0:
            return None
        price_raw = (sqrt_p / 2**96) ** 2
        price = price_raw * (10**18) / (10**6)
        return price
    except Exception as e:
        print("Uni error:", e)
        return None

def get_aero_price():
    try:
        router = w3.eth.contract(address=Web3.to_checksum_address(AERO_ROUTER), abi=AERO_ABI)
        routes = [{"from": Web3.to_checksum_address(WETH), "to": Web3.to_checksum_address(USDC), "stable": False, "factory": Web3.to_checksum_address(AERO_FACTORY)}]
        amounts = router.functions.getAmountsOut(10**18, routes).call()
        return amounts[-1] / 10**6
    except Exception as e:
        print("Aero error:", e)
        return None

cycle = 0
while True:
    cycle += 1
    uni = get_uni_price()
    aero = get_aero_price()
    print(f"\n{'='*50}")
    print(f"Cycle #{cycle} | Min profit: ${MIN_PROFIT}")
    print(f"Uniswap V3 : ${uni:.4f}" if uni else "Uniswap V3 : unavailable")
    print(f"Aerodrome : ${aero:.4f}" if aero else "Aerodrome : unavailable")
    if uni and aero:
        diff = abs(uni - aero)
        profit = (diff / max(uni, aero)) * 40000 - 36
        print(f"Price diff : ${diff:.4f}")
        print(f"Est profit : ${profit:.2f}")
        if profit >= MIN_PROFIT:
            print("*** OPPORTUNITY FOUND ***")
    time.sleep(10)
