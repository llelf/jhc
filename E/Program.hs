module E.Program where

import Prelude hiding(putStrLn, putStr,print)
import Control.Monad.Identity
import Data.Monoid
import List
import Maybe
import qualified Data.Map as Map

import StringTable.Atom
import DataConstructors
import Doc.DocLike
import Doc.PPrint
import CharIO
import Doc.Pretty
import E.E
import E.Show
import E.TypeCheck
import FrontEnd.Class
import Util.Gen hiding(putErrLn)
import Name.Id
import Name.Name
import Options
import qualified IO
import qualified FlagDump as FD
import qualified Stats


data ProgramType = SubProgram Bool | MainProgram | MainComponent

data Program = Program {
    progExternalNames :: IdSet,
    progClassHierarchy :: ClassHierarchy,
    progCombinators :: [Comb],
    progDataTable :: DataTable,
    progEntryPoints :: [TVr],
    progMainEntry :: TVr,
    progModule :: Module,
    progPasses :: [String],       -- ^ record of passes the program goes through
    progUsedIds :: IdSet,         -- ^ filled in by occurance info collection
    progFreeIds :: IdSet,         -- ^ filled in by occurance info collection
    progType    :: ProgramType,
    progStats :: Stats.Stat
    }


program = Program {
    progExternalNames = mempty,
    progClassHierarchy = mempty,
    progCombinators = mempty,
    progDataTable = mempty,
    progEntryPoints = mempty,
    progMainEntry = tvr,
    progModule = mainModule,
    progPasses = [],
    progUsedIds = mempty,
    progFreeIds = mempty,
    progType = MainProgram,
    progStats = mempty
    }


programDs :: Program -> [(TVr,E)]
programDs prog = [ (t,e)  | Comb { combHead = t, combBody = e }  <- progCombinators prog]

programSetDs :: [(TVr,E)] -> Program -> Program
programSetDs ds prog | flint && hasRepeatUnder (tvrIdent . fst) ds = error $ "programSetDs: program has redundant definitions: \n" ++ intercalate "\n"  (sort $ map (show . tvrShowName . fst) ds)
programSetDs ds prog | flint && any (not . isValidAtom) (map (tvrIdent . fst) ds) = error $ "programSetDs: trying to set non unique top level name: \n" ++ intercalate "\n"  (sort $ map (show . tvrShowName . fst) ds)
programSetDs ds prog = prog {
    progMainEntry = f (progMainEntry prog),
    progEntryPoints = map f (progEntryPoints prog),
    progCombinators = [ emptyComb { combHead = t, combBody = e } | (t,e) <- ds ]
    } where
    f tvr | Just n <- Map.lookup (tvrIdent tvr) mp = n
          | otherwise = tvr
    mp = Map.fromList [ (tvrIdent t,t) | (t,_) <- ds ]

programAddDs :: [(TVr,E)] -> Program -> Program
programAddDs ds prog = prog { progCombinators = [ emptyComb { combHead = t, combBody = e } | (t,e) <- ds ] ++ progCombinators prog }

programE :: Program -> E
programE prog = ELetRec (programDs prog) (EVar (progMainEntry prog))

programEsMap :: Monad m => Program -> m (Map.Map Name (TVr,E))
programEsMap prog = do
    let f d@(v,_) = case fromId (tvrIdent v) of
            Just n -> return (n,d)
            Nothing -> fail $ "Program.programEsMap: top level var with temporary name " ++ show v
    xs <- mapM f (programDs prog)
    return (Map.fromList xs)

programMapBodies f prog = do
     ds <- sequence [ f e >>= return . (,) t | (t,e) <- programDs prog ]
     return $ programSetDs ds prog

programMapDs f prog = do
     ds <- mapM f (programDs prog)
     return $ programSetDs ds prog

programMapDs_ f prog = mapM_ f (programDs prog)

hPrintProgram fh prog@Program {progCombinators = cs, progDataTable = dataTable } = do
    sequence_ $ intersperse (hPutStrLn fh "") [ hPrintCheckName fh dataTable v e | Comb { combHead = v, combBody = e } <- cs]
    when (progMainEntry prog /= tvr) $
        hPutStrLn fh $ "MainEntry: " ++ pprint (progMainEntry prog)
    when (progEntryPoints prog /= [progMainEntry prog]) $
        hPutStrLn fh $ "EntryPoints: " ++ hsep (map pprint (progEntryPoints prog))

printProgram prog = hPrintProgram IO.stderr prog

printCheckName'' = hPrintCheckName IO.stderr

hPrintCheckName :: IO.Handle -> DataTable -> TVr -> E -> IO ()
hPrintCheckName fh dataTable tvr e = do
    let (ty,pty) = case inferType dataTable [] e of
            Left err -> (Unknown,vcat $ map text (intersperse "---" $ tail err))
            Right ty -> (ty,pprint ty)
        tmatch = isJust $ match (const Nothing) [] ty (tvrType tvr)
    when (dump FD.EInfo || verbose2) $ hPutStrLn fh (show $ tvrInfo tvr)
    hPutStrLn fh (render $ hang 4 (pprint tvr <+> text "::" <+> (pprint $ tvrType tvr)))
    when (not tmatch || dump FD.EVerbose) $
        hPutStrLn fh (render $ hang 4 (pprint tvr <+> text "::" <+> pty))
    hPutStrLn fh (render $ hang 4 (pprint tvr <+> equals <+> pprint e))
