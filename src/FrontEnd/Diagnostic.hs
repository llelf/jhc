module FrontEnd.Diagnostic (
       Diagnostic(..),
       makeMsg,
       locMsg,
       locSimple,
       simpleMsg,
       typeError,
       TypeError (..),
       ) where

import Util.Std
import FrontEnd.SrcLoc
import PackedString
import Util.DocLike
import qualified Text.PrettyPrint.HughesPJ as P

data TypeError = Unification String | Failure String | UnexpectedType String

typeError :: TypeError -> [Diagnostic] -> String
typeError err ds =
             "What:  " ++ whatStr ++ "\n" ++
             "Why:   " ++ whyStr ++ "\n" ++
             "Where: " ++ dumpDiagnostic 3 ds where
   (whatStr, whyStr) = case err of
           Unification s -> ("type unification error", s)
           Failure s ->  ("failure", s)
           UnexpectedType s -> ("unexpected type", s)

data Diagnostic = Msg { msgSrcLoc :: Maybe SrcLoc, msgString :: String, msgFull :: Bool}
   deriving Show

diagEmpty = Msg { msgSrcLoc = Nothing, msgString = "diagnostic unknown", msgFull = False }

{- given a description, make a Diagnostic out of it -}
simpleMsg :: String -> Diagnostic
simpleMsg msgString = diagEmpty { msgString}

{- given a description and some data to be shown make a diagnostic -}
-- makeMsg :: PrettyShow a => Description -> a -> Diagnostic
makeMsg :: String -> String -> Diagnostic
makeMsg description val = simpleMsg (description ++ "\n   " ++ val)

{- given a srcloc and a description, make a diagnostic -}
locSimple :: SrcLoc -> String -> Diagnostic
locSimple loc desc = withASrcLoc loc (simpleMsg desc)

{- like locSimple but also takes data to be displayed -}
-- locMsg :: PrettyShow a => SrcLoc -> Description -> a -> Diagnostic
locMsg :: SrcLoc -> String -> String -> Diagnostic
locMsg loc desc val = locSimple loc (desc ++ "\n   " ++ val)

{- take a diagnostic stack and a 'maxContext' and display the
   most recent maxContext number of lines from the stack -}
dumpDiagnostic :: Int -> [Diagnostic] -> String
dumpDiagnostic maxContext diagnostics
   = mostRecentASrcLoc ++ "\n" ++ (showDiagnostics . take maxContext $ diagnostics) where
     mostRecentASrcLoc = case msum (map msgSrcLoc diagnostics) of
                Just (SrcLoc fn line col)
                    -> "on line " ++ show line ++ " in " ++ unpackPS fn
                _ -> "no line information"

{- display an entire stack of diagnostics (it displays the top of
   the stack first, so most calls will have to reverse the stack
   before getting here -}
showDiagnostics :: [Diagnostic] -> String
showDiagnostics diags
    = case diags of
        [onlyOne] -> "The error was " ++ showDiag onlyOne
        _         -> showDiagnostics' diags
    where
    showDiagnostics' [] = ""
    showDiagnostics' (diag:diags)
       = case diags of
         --[] -> "\nSo the error was " ++ showDiag diag  -- innermost error
         [] -> showDiag diag  -- innermost error
         _  -> showDiag diag ++ "\n" ++ showDiagnostics' diags

    showDiag Msg { msgString } = msgString
         {- I think that all these line numbers are probably excessive -}
--         ++ case maybeLoc of
 --            Just srcloc -> "\t\t{- on line " ++ show (srcLine srcloc) ++ " -}"  -- discreetly display line nums
  --            _ -> ""

srcLine :: SrcLoc -> Int
srcLine = srcLocLine

withASrcLoc :: SrcLoc -> Diagnostic -> Diagnostic
withASrcLoc loc x | loc == mempty = x
withASrcLoc loc msg@Msg { msgString } = msg { msgSrcLoc = Just loc }
