{-# LANGUAGE DeriveDataTypeable, CPP #-}

module CabalCargs.Args where

import System.Console.CmdArgs
import CabalCargs.Field (Field)
import CabalCargs.Formatting (Formatting)
 
#ifdef CABAL
import Data.Version (showVersion)
import Paths_cabal_cargs (version)
#endif


-- | The command line arguments of the cabal-cargs command.
data Args = Args
   { library    :: Bool
   , executable :: [String]
   , testSuite  :: [String]
   , benchmark  :: [String]
   , only       :: [Field]
   , format     :: Formatting
   , sourceFile :: Maybe FilePath
   , cabalFile  :: Maybe FilePath
   }
   deriving (Data, Typeable, Show, Eq)


get :: IO Args
get = cmdArgs $ Args
   { library    = def &= help "Only the compiler args of the library section are printed out."
   , executable = def &= typ "NAME" &= help "Only the compiler args of the library section are printed out."
   , testSuite  = def &= typ "NAME" &= help "Only the compiler args of the test suite section are printed out."
   , benchmark  = def &= typ "NAME" &= help "Only the compiler args of the benchmark section are printed out."
   , only       = def &= typ "FIELD" &= help "Only the specified compiler args are printed out, otherwise all args are printed out. The field name equals the ones in the cabal file, just the '-' replaced by a '_' e.g.: hs_source_dirs, ghc_options, cpp_options ..."
   , format     = def &= typ "FORMAT" &= help "How the print out should be formated: ghc, hdevtools, pure."
   , sourceFile = def &= typ "FILE" &= help "If given, then the cabal file is searched for a matching section. If multiple sections match, then all sections are used."
   , cabalFile  = def &= typ "FILE" &= help "If not given, then a cabal file is searched upwards the directory tree."
   }
   &= program "cabal-cargs"
   &= summary ""
   &= help "A command line program for extracting compiler arguments from a cabal file."
   &= helpArg [explicit, name "help", name "h"]
   &= versionArg [explicit, name "version", name "v", summary versionInfo]


versionInfo :: String
versionInfo =
#ifdef CABAL
   "cabal-cargs version " ++ showVersion version
#else
   "cabal-cargs version unknown (not built with cabal)"
#endif
