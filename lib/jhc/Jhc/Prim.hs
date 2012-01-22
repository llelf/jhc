{-# LANGUAGE UnboxedTuples, ForeignFunctionInterface, NoImplicitPrelude #-}
module Jhc.Prim(module Jhc.Prim.Bits, module Jhc.Prim) where

import Jhc.Prim.Bits
import Jhc.String

infixr 5  :
data [] a =  a : ([] a) | []

newtype IO a = IO (World__ -> (# World__, a #))

data World__ :: #

data Int
data Char = Char Char__

type Bool__ = Bits16_ -- Change to Bits1_ when the time comes
type Int__  = Bits32_
type Char__ = Bits32_
type Enum__ = Bits16_
type Addr__ = BitsPtr_

-- | when no exception wrapper is wanted
runNoWrapper :: IO a -> World__ -> World__
runNoWrapper (IO run) w = case run w of (# w, _ #) -> w

-- | this is wrapped around arbitrary expressions and just evaluates them to whnf
foreign import primitive "seq" runRaw :: a -> World__ -> World__

foreign import primitive "unsafeCoerce" unsafeCoerce__ :: a -> b

-- like 'const' but creates an artificial dependency on its second argument to guide optimization.
foreign import primitive dependingOn :: a -> b -> a
