module Atom(
    Atom(),
    Atom.toString,
    FromAtom(..),
    ToAtom(..),
    dumpAtomTable,
    fromPackedStringIO,
    fromString,
    fromStringIO,
    toPackedString,
    atomIndex,
    unsafeAtomToInt,
    unsafeIntToAtom,
    intToAtom
    ) where

import Char
import Foreign
import Control.Monad
import Data.Binary
import Data.Binary.Get
import Data.Binary.Put
import PackedString(PackedString(..))
import qualified Data.ByteString as BS
import StringTable.Atom


toString :: Atom -> String
toString = fromAtom

fromString :: String -> Atom
fromString string = toAtom string


atomIndex,unsafeAtomToInt :: Atom -> Int
atomIndex = fromAtom
unsafeAtomToInt = fromAtom

instance FromAtom (String -> String) where
    fromAtom x = shows (fromAtom x :: String)

instance ToAtom PackedString where
    toAtomIO (PS x) = toAtomIO x
instance FromAtom PackedString where
    fromAtomIO atom = PS `liftM` fromAtomIO atom


fromStringIO :: String -> IO Atom
fromStringIO cs = toAtomIO cs

fromPackedStringIO :: PackedString -> IO Atom
fromPackedStringIO ps = toAtomIO ps


dumpAtomTable = do
    dumpTable
    dumpStringTableStats


toPackedString :: Atom -> PackedString
toPackedString = fromAtom

instance Binary Atom where
    get = do
        x <- getWord8
        bs <- getBytes (fromIntegral x)
        return $ toAtom bs
    put a = do
        let bs = fromAtom a
        putWord8 $ fromIntegral $ BS.length bs
        putByteString bs

