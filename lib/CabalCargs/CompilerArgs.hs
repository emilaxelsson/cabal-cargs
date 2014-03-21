{-# Language PatternGuards, TemplateHaskell, Rank2Types #-}

module CabalCargs.CompilerArgs
   ( CompilerArgs(..)
   , fromCmdArgs
   , fromSpec
   ) where

import CabalCargs.Spec (Spec)
import qualified CabalCargs.Spec as Spec
import qualified CabalCargs.Args as A
import qualified CabalCargs.Sections as S
import qualified CabalCargs.Field as F
import qualified CabalCargs.Fields as Fs
import qualified CabalCargs.BuildInfo as B
import Data.List (nub, foldl')
import Control.Applicative ((<$>))
import Control.Lens
import qualified Filesystem.Path.CurrentOS as FP
import Filesystem.Path ((</>))


-- | The collected compiler args from the cabal file. Till the field 'packageDB'
--   all fields represent the equaliy named fields ('-' replaced by CamelCase)
--   from the cabal file.
data CompilerArgs = CompilerArgs 
   { hsSourceDirs        :: [FilePath]
   , ghcOptions          :: [String]
   , defaultExtensions   :: [String]
   , defaultLanguage     :: [String]
   , cppOptions          :: [String]
   , cSources            :: [FilePath]
   , ccOptions           :: [String]
   , extraLibDirs        :: [FilePath]
   , extraLibraries      :: [String]
   , ldOptions           :: [String]
   , includeDirs         :: [FilePath]
   , includes            :: [String]
   , packageDB           :: Maybe FilePath -- ^ the path to the package database of the cabal sandbox
   , autogenHsSourceDirs :: [FilePath]     -- ^ dirs of automatically generated haskell source files by cabal (e.g. Paths_*)
   , autogenIncludeDirs  :: [FilePath]     -- ^ dirs of automatically generated include files by cabal
   , autogenIncludes     :: [String]       -- ^ automatically generated include files by cabal (e.g. cabal_macros.h)
   , hdevtoolsSocket     :: Maybe FilePath -- ^ the path to the hdevtools socket file
   }
   deriving (Show, Eq)


makeLensesFor [ ("hsSourceDirs"       , "hsSourceDirsL")
              , ("ghcOptions"         , "ghcOptionsL")
              , ("defaultExtensions"  , "defaultExtensionsL")
              , ("defaultLanguage"    , "defaultLanguageL")
              , ("cppOptions"         , "cppOptionsL")
              , ("cSources"           , "cSourcesL")
              , ("ccOptions"          , "ccOptionsL")
              , ("extraLibDirs"       , "extraLibDirsL")
              , ("extraLibraries"     , "extraLibrariesL")
              , ("ldOptions"          , "ldOptionsL")
              , ("includeDirs"        , "includeDirsL")
              , ("includes"           , "includesL")
              , ("packageDB"          , "packageDBL")
              , ("autogenHsSourceDirs", "autogenHsSourceDirsL")
              , ("autogenIncludeDirs" , "autogenIncludeDirsL")
              , ("autogenIncludes"    , "autogenIncludesL")
              , ("hdevtoolsSocket"    , "hdevtoolsSocketL")
              ] ''CompilerArgs

type Error = String


-- | Create a 'CompilerArgs' by the command line arguments given to 'cabal-cargs'.
fromCmdArgs :: A.Args -> IO (Either Error CompilerArgs)
fromCmdArgs args = (fromSpec <$>) <$> Spec.fromCmdArgs args


-- | Create a 'CompilerArgs' and collect the compiler args specified by 'Spec'.
fromSpec :: Spec -> CompilerArgs
fromSpec spec =
   case Spec.sections spec of
        S.Sections sections ->
           absolutePaths $ foldl' collectFromSection defaultCompilerArgs sections

        S.AllSections ->
           absolutePaths $ collectFields buildInfos defaultCompilerArgs

   where
      absolutePaths cargs
         | Spec.relativePaths spec
         = cargs

         | otherwise
         = cargs & hsSourceDirsL            %~ map prependCabalDir
                 & cSourcesL                %~ map prependCabalDir
                 & extraLibDirsL            %~ map prependCabalDir
                 & includeDirsL             %~ map prependCabalDir
                 & autogenHsSourceDirsL     %~ map prependCabalDir
                 & autogenIncludeDirsL      %~ map prependCabalDir
                 & packageDBL . _Just       %~ prependCabalDir
                 & hdevtoolsSocketL . _Just %~ prependCabalDir
         where
            prependCabalDir path = FP.encodeString $ cabalDir </> FP.decodeString path
            cabalDir             = FP.directory . FP.decodeString $ Spec.cabalFile spec

      collectFromSection cargs section =
         collectFields (buildInfosOf section) cargs

      collectFields buildInfos cargs =
        foldl' (addCarg buildInfos) cargs fields
        where
           addCarg _ cargs F.Package_Db  =
              cargs & packageDBL .~ Spec.packageDB spec

           addCarg _ cargs F.Autogen_Hs_Source_Dirs
              | Just distDir <- Spec.distDir spec
              = cargs & autogenHsSourceDirsL .~ [distDir ++ "/build/autogen"]

              | otherwise
              = cargs

           addCarg _ cargs F.Autogen_Include_Dirs
              | Just distDir <- Spec.distDir spec
              = cargs & autogenIncludeDirsL .~ [distDir ++ "/build/autogen"]

              | otherwise
              = cargs

           addCarg _ cargs F.Autogen_Includes
              | Just _ <- Spec.distDir spec
              = cargs & autogenIncludesL .~ ["cabal_macros.h"]

              | otherwise
              = cargs

           addCarg _ cargs F.Hdevtools_Socket =
              cargs & hdevtoolsSocketL .~ Just ".hdevtools.sock"

           addCarg buildInfos cargs field =
              cargs & (fieldL field) %~ nub . (++ buildInfoFields)
              where
                 buildInfoFields = concat $ map (^. B.field field) buildInfos

           fields = case Spec.fields spec of
                         Fs.Fields fs -> fs
                         _            -> F.allFields

      buildInfos           = B.buildInfos (Spec.condVars spec) (Spec.cabalPackage spec)
      buildInfosOf section = B.buildInfosOf section (Spec.condVars spec) (Spec.cabalPackage spec)


fieldL :: F.Field -> Lens' CompilerArgs [String]
fieldL F.Hs_Source_Dirs         = hsSourceDirsL
fieldL F.Ghc_Options            = ghcOptionsL
fieldL F.Default_Extensions     = defaultExtensionsL
fieldL F.Default_Language       = defaultLanguageL
fieldL F.Cpp_Options            = cppOptionsL
fieldL F.C_Sources              = cSourcesL
fieldL F.Cc_Options             = ccOptionsL
fieldL F.Extra_Lib_Dirs         = extraLibDirsL
fieldL F.Extra_Libraries        = extraLibrariesL
fieldL F.Ld_Options             = ldOptionsL
fieldL F.Include_Dirs           = includeDirsL
fieldL F.Includes               = includesL
fieldL F.Package_Db             = error $ "Unexpected field Package_Db for CabalCargs.CompilerArgs.fieldL!"
fieldL F.Autogen_Hs_Source_Dirs = autogenHsSourceDirsL
fieldL F.Autogen_Include_Dirs   = autogenIncludeDirsL
fieldL F.Autogen_Includes       = autogenIncludesL
fieldL F.Hdevtools_Socket       = error $ "Unexpected field Hdevtools_Socket for CabalCargs.CompilerArgs.fieldL!"


defaultCompilerArgs :: CompilerArgs
defaultCompilerArgs = CompilerArgs
   { hsSourceDirs        = []
   , ghcOptions          = []
   , defaultExtensions   = []
   , defaultLanguage     = []
   , cppOptions          = []
   , cSources            = []
   , ccOptions           = []
   , extraLibDirs        = []
   , extraLibraries      = []
   , ldOptions           = []
   , includeDirs         = []
   , includes            = []
   , packageDB           = Nothing
   , autogenHsSourceDirs = []
   , autogenIncludeDirs  = []
   , autogenIncludes     = []
   , hdevtoolsSocket     = Nothing
   }
