{-# OPTIONS_JHC -N -funboxed-tuples #-}

module Jhc.IO(
    IO(..),
    UIO(),
    UIO_(),
    World__(),
    catch,
    dependingOn,
    fixIO,
    ioError,
    runExpr,
    runMain,
    runNoWrapper,
    exitFailure,
    strictReturn,
    unsafeInterleaveIO,
    error,
    IOError(),
    showIOError,
    userError,
    unsafePerformIO,
    unsafePerformIO'
    ) where

import Jhc.Prim
import Jhc.Basics
import Jhc.Order
import Foreign.C.Types
import qualified Jhc.Options


-- basic types

newtype IO a = IO (World__ -> (# World__, a #))

unIO :: IO a -> World__ -> (# World__, a #)
unIO (IO x) = x

type UIO a = World__ -> (# World__, a #)
type UIO_ = World__ -> World__

-- unsafe operations

unsafePerformIO :: IO a -> a
unsafePerformIO x = case newWorld__ x of
    world -> case errorContinuation x of
        IO y -> case y world of
            (# _, a #) -> a

-- | same as unsafePerformIO, but doesn't set up error handler
unsafePerformIO' :: IO a -> a
unsafePerformIO' x = case newWorld__ x of
    world -> case (unIO x) world of
            (# _, a #) -> a

-- we have to replace the error handler because the context might have quit by the time the value is evaluated.
unsafeInterleaveIO :: IO a -> IO a
unsafeInterleaveIO action = IO $ \w -> (# w , case action' w of (# _,  a #) -> a #)
    where IO action' = errorContinuation action


-- IO Exception handling

newtype IOError = IOError String
    deriving(Eq)

showIOError :: IOError -> String
showIOError (IOError x) = x

userError       :: String  -> IOError
userError str	=  IOError  str

showError :: IOError -> IO b
showError (IOError z) = putErrLn z `thenIO_` exitFailure

errorContinuation :: IO a -> IO a
errorContinuation x = catch x showError

ioError    ::  IOError -> IO a
ioError e  = case Jhc.Options.target of
    Jhc.Options.GhcHs -> IO $ \w -> raiseIO__ e w
    _ -> showError e


catch :: IO a -> (IOError -> IO a) -> IO a
catch (IO m) k =  case Jhc.Options.target of
    Jhc.Options.GhcHs -> IO $ \s -> catch__ m (\ex -> unIO (k ex)) s
    _ -> IO m  -- no catching on other targets just yet


-- IO fixpoint operation

data FixIO a = FixIO World__ a

fixIO :: (a -> IO a) -> IO a
fixIO k = IO $ \w -> let
            r = case k ans of
                    IO z -> case z w of
                        (# w, r #) -> FixIO w r
            ans = case r of
                FixIO _ z -> z
               in case r of
                FixIO w z -> (# w, z #)


-- some primitives


-- | this creates a new world object that artificially depends on its argument to avoid CSE.
foreign import primitive newWorld__ :: a -> World__
foreign import primitive "drop__" worldDep__ :: forall b. World__ -> b -> b

-- | this will return a value making it artificially depend on the state of the world. any uses of this value are guarenteed not to float before this point in the IO monad.
strictReturn :: a -> IO a
strictReturn a = IO $ \w -> (# w, worldDep__ w a #)

{-# INLINE runMain #-}
-- | this is wrapped around 'main' when compiling programs. it catches any exceptions and prints them to the screen and dies appropriatly.
runMain :: IO a -> World__ -> World__
runMain main w = case run w of
        (# w,  _ #) -> w
    where
    IO run = catch main $ \e ->
            putErrLn "\nUncaught Exception:" `thenIO_`
            putErrLn (showIOError e)         `thenIO_`
            exitFailure



-- | when no exception wrapper is wanted
runNoWrapper :: IO a -> World__ -> World__
runNoWrapper (IO run) w = case run w of (# w, _ #) -> w

exitFailure :: IO a
exitFailure = IO $ \w -> exitFailure__ w

foreign import primitive exitFailure__ :: World__ -> (# World__, a #)


thenIO_ :: IO a -> IO b -> IO b
IO a `thenIO_` IO b = IO $ \w -> case a w of
    (# w', _ #) -> b w'

IO a `thenIO` b = IO $ \w -> case a w of
    (# w', v #) -> unIO (b v) w'

{-# NOINLINE error #-}
error s = unsafePerformIO' $
    putErrLn "error:"  `thenIO_`
    putErrLn s         `thenIO_`
    exitFailure

-- | no the implicit unsafeCoerce__ here!
foreign import primitive catch__ :: (World__ -> (# World__,a #)) -> (b -> World__ -> (# World__,a #)) -> World__ -> (# World__,a #)
foreign import primitive raiseIO__ :: a -> World__ -> (# World__,b #)


putErrLn :: [Char] -> IO ()
putErrLn [] = putChar '\n'
putErrLn (c:cs) = putChar c `thenIO_` putErrLn cs
putChar :: Char -> IO ()
putChar c = c_putwchar (charToCWchar c)

foreign import primitive "integralCast" charToCWchar :: Char -> CWchar
foreign import ccall "stdio.h putwchar" c_putwchar :: CWchar -> IO ()

