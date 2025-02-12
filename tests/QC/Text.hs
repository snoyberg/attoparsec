{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
module QC.Text (tests) where

import Control.Applicative ((<$>))
import Prelude hiding (takeWhile)
import Test.Framework.Providers.QuickCheck2 (testProperty)
import Test.QuickCheck
import qualified Data.Attoparsec.Text as P
import qualified Data.Attoparsec.Text.Lazy as PL
import qualified Data.Text as T
import qualified Data.Text.Lazy as L

instance Arbitrary T.Text where
    arbitrary   = T.pack <$> arbitrary

instance Arbitrary L.Text where
    arbitrary   = sized $ \n -> resize (round (sqrt (toEnum n :: Double)))
                  ((L.fromChunks . map (T.pack . nonEmpty)) <$> arbitrary)
      where nonEmpty (NonEmpty a) = a

-- Naming.

{-
label (NonEmpty s) = case parse (anyChar <?> s) T.empty of
                            (_, Left err) -> s `isInfixOf` err
                            _             -> False
-}

-- Basic byte-level combinators.

maybeP p = PL.maybeResult . PL.parse p

defP p = PL.parse p

satisfy w s = maybeP (P.satisfy (<=w)) (L.cons w s) == Just w

char w s = maybeP (P.char w) (L.cons w s) == Just w

anyChar s
    | L.null s  = p == Nothing
    | otherwise = p == Just (L.head s)
  where p = maybeP P.anyChar s

notChar w (NonEmpty s) = maybeP (P.notChar w) bs == if v == w
                                                      then Nothing
                                                      else Just v
    where v = L.head bs
          bs = L.pack s

string s t = maybeP (P.string s') (s `L.append` t) == Just s'
  where s' = toStrict s

toStrict = T.concat . L.toChunks

skipWhile w s =
    let t = L.dropWhile (<=w) s
    in case defP (P.skipWhile (<=w)) s of
         PL.Done t' () -> t == t'
         _             -> False

takeCount (Positive k) s =
    case maybeP (P.take k) s of
      Nothing -> fromIntegral k > L.length s
      Just s' -> fromIntegral k <= L.length s

takeWhile w s =
    let (h,t) = L.span (==w) s
    in case defP (P.takeWhile (==w)) s of
         PL.Done t' h' -> t == t' && toStrict h == h'
         _             -> False

takeWhile1 w s =
    let s'    = L.cons w s
        (h,t) = L.span (<=w) s'
    in case defP (P.takeWhile1 (<=w)) s' of
         PL.Done t' h' -> t == t' && toStrict h == h'
         _             -> False

takeTill w s =
    let (h,t) = L.break (==w) s
    in case defP (P.takeTill (==w)) s of
         PL.Done t' h' -> t == t' && toStrict h == h'
         _             -> False

takeWhile1_empty = maybeP (P.takeWhile1 undefined) L.empty == Nothing

endOfInput s = maybeP P.endOfInput s == if L.null s
                                        then Just ()
                                        else Nothing

tests = [
    testProperty "satisfy" satisfy,
    testProperty "char" char,
    testProperty "notChar" notChar,
    testProperty "anyChar" anyChar,
    testProperty "string" string,
    testProperty "skipWhile" skipWhile,
    testProperty "takeCount" takeCount,
    testProperty "takeWhile" takeWhile,
    testProperty "takeWhile1" takeWhile1,
    testProperty "takeWhile1_empty" takeWhile1_empty,
    testProperty "takeTill" takeTill,
    testProperty "endOfInput" endOfInput
  ]
