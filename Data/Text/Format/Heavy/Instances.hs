{-# LANGUAGE OverloadedStrings, FlexibleInstances, UndecidableInstances #-}
-- | This module contains Formatable and VarContainer instances for most used types.
module Data.Text.Format.Heavy.Instances
  (-- * Utility data types
   Single (..), Shown (..),
   -- * Generic formatters
   genericIntFormat, genericFloatFormat
  ) where

import Data.String
import Data.Char
import Data.Default
import qualified Data.Map as M
import qualified Data.Text as T
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Builder as B
import Data.Text.Lazy.Builder.Int (decimal, hexadecimal)

import Data.Text.Format.Heavy.Types
import Data.Text.Format.Heavy.Parse
import Data.Text.Format.Heavy.Build

instance IsString Format where
  fromString str = parseFormat' (fromString str)

instance IsVarFormat GenericFormat where
  parseVarFormat text = either (Left . show) Right $ parseGenericFormat text

---------------------- Generic formatters -------------------------------------------

-- | Generic formatter for integer types
genericIntFormat :: Integral a => VarFormat -> a -> B.Builder
genericIntFormat Nothing x = formatInt def x
genericIntFormat (Just fmtStr) x =
    case parseGenericFormat fmtStr of
      Left err -> error $ show err
      Right fmt -> formatInt fmt x

-- | Generic formatter for floating-point types
genericFloatFormat :: RealFloat a => VarFormat -> a -> B.Builder
genericFloatFormat Nothing x = formatFloat def x
genericFloatFormat (Just fmtStr) x =
    case parseGenericFormat fmtStr of
      Left err -> error $ show err
      Right fmt -> formatFloat fmt x

------------------------ Formatable instances -------------------------------------------

instance Formatable Int where
  formatVar fmt x = genericIntFormat fmt x

instance Formatable Integer where
  formatVar fmt x = genericIntFormat fmt x

instance Formatable Float where
  formatVar fmt x = genericFloatFormat fmt x

instance Formatable Double where
  formatVar fmt x = genericFloatFormat fmt x

instance Formatable String where
  formatVar Nothing text = formatStr def (fromString text)
  formatVar (Just fmtStr) text =
    case parseGenericFormat fmtStr of
      Left err -> error $ show err
      Right fmt -> formatStr fmt (fromString text)

instance Formatable T.Text where
  formatVar Nothing text = formatStr def $ TL.fromStrict text
  formatVar (Just fmtStr) text =
    case parseGenericFormat fmtStr of
      Left err -> error $ show err
      Right fmt -> formatStr fmt $ TL.fromStrict text

instance Formatable TL.Text where
  formatVar Nothing text = formatStr def text
  formatVar (Just fmtStr) text =
    case parseGenericFormat fmtStr of
      Left err -> error $ show err
      Right fmt -> formatStr fmt text

-- | Container for single parameter.
data Single a = Single {getSingle :: a}
  deriving (Eq, Show)

-- data Many a = Many {getMany :: [a]}
--   deriving (Eq, Show)

instance Formatable a => Formatable (Single a) where
  formatVar fmt (Single x) = formatVar fmt x

-- | Values packed in Shown will be formatted using their Show instance.
--
-- For example,
--
-- @
-- formatText "values: {}." (Shown (True, False)) ==> "values: (True, False)."
-- @
data Shown a = Shown { shown :: a }
  deriving (Eq)

instance Show a => Show (Shown a) where
  show (Shown x) = show x

instance Show a => Formatable (Shown a) where
  formatVar _ (Shown x) = B.fromLazyText $ TL.pack $ show x

instance Formatable a => Formatable (Maybe a) where
  formatVar Nothing Nothing = mempty
  formatVar (Just "") Nothing = mempty
  formatVar fmt (Just x) = formatVar fmt x

instance (Formatable a, Formatable b) => Formatable (Either a b) where
  formatVar fmt (Left x) = formatVar fmt x
  formatVar fmt (Right y) = formatVar fmt y

------------------------------- VarContainer instances -------------------------------------

instance Formatable a => VarContainer (Single a) where
  lookupVar "0" (Single x) = Just $ Variable x
  lookupVar _ _ = Nothing

instance (Formatable a, Formatable b) => VarContainer (a, b) where
  lookupVar "0" (a,_) = Just $ Variable a
  lookupVar "1" (_,b) = Just $ Variable b
  lookupVar _ _ = Nothing
  
instance (Formatable a, Formatable b, Formatable c) => VarContainer (a, b, c) where
  lookupVar "0" (a,_,_) = Just $ Variable a
  lookupVar "1" (_,b,_) = Just $ Variable b
  lookupVar "2" (_,_,c) = Just $ Variable c
  lookupVar _ _ = Nothing
  
instance (Formatable a, Formatable b, Formatable c, Formatable d) => VarContainer (a, b, c, d) where
  lookupVar "0" (a,_,_,_) = Just $ Variable a
  lookupVar "1" (_,b,_,_) = Just $ Variable b
  lookupVar "2" (_,_,c,_) = Just $ Variable c
  lookupVar "3" (_,_,_,d) = Just $ Variable d
  lookupVar _ _ = Nothing

instance (Formatable a, Formatable b, Formatable c, Formatable d, Formatable e)
     => VarContainer (a, b, c, d, e) where
  lookupVar "0" (a,_,_,_,_) = Just $ Variable a
  lookupVar "1" (_,b,_,_,_) = Just $ Variable b
  lookupVar "2" (_,_,c,_,_) = Just $ Variable c
  lookupVar "3" (_,_,_,d,_) = Just $ Variable d
  lookupVar "4" (_,_,_,_,e) = Just $ Variable e
  lookupVar _ _ = Nothing

instance (Formatable a, Formatable b, Formatable c, Formatable d, Formatable e, Formatable f)
     => VarContainer (a, b, c, d, e, f) where
  lookupVar "0" (a,_,_,_,_,_) = Just $ Variable a
  lookupVar "1" (_,b,_,_,_,_) = Just $ Variable b
  lookupVar "2" (_,_,c,_,_,_) = Just $ Variable c
  lookupVar "3" (_,_,_,d,_,_) = Just $ Variable d
  lookupVar "4" (_,_,_,_,e,_) = Just $ Variable e
  lookupVar "5" (_,_,_,_,_,f) = Just $ Variable f
  lookupVar _ _ = Nothing

instance Formatable a => VarContainer [a] where
  lookupVar name lst =
    if not $ TL.all isDigit name
      then Nothing
      else let n = read (TL.unpack name)
           in  if n >= length lst
               then Nothing
               else Just $ Variable (lst !! n)
  
instance Formatable x => VarContainer [(TL.Text, x)] where
  lookupVar name pairs = Variable `fmap` lookup name pairs

instance Formatable x => VarContainer (M.Map TL.Text x) where
  lookupVar name pairs = Variable `fmap` M.lookup name pairs

