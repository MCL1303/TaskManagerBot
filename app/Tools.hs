{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Tools
(
    -- * I/O tools
    loadOffset,
    loadToken,
    saveOffset,
    -- * Log tool
    putLog,
    -- * Control flow
    untilRight,
    -- * Message recognizing
    readCommand
) where

import           Control.Exception    (Exception, IOException, catch, throwIO)
import           Data.Char            (isSpace)
import           Data.Monoid          ((<>))
import           Data.Text            as Text (Text, head, length, pack, strip,
                                               tail, takeWhile, uncons, unpack)
import qualified Data.Text.IO         as Text
import           System.IO            (IOMode (ReadWriteMode), hGetContents,
                                       hPutStrLn, openFile, stderr)
import           Web.Telegram.API.Bot (Token (Token))

-- | Puts message in log
putLog :: String -- ^ Error message
       -> IO()
putLog = hPutStrLn stderr

data TokenLoadException = TokenLoadException
    {tle_cause :: IOException, tle_file :: FilePath}
    deriving Show
instance Exception TokenLoadException

loadToken :: FilePath -> IO Token
loadToken fileName = do
    rawToken <- Text.readFile fileName `catch` handleReadFile
    pure . Token $ "bot" <> strip rawToken
  where
    handleReadFile e =
        throwIO TokenLoadException{tle_cause = e, tle_file = fileName}

loadOffset :: FilePath -> IO (Maybe Int)
loadOffset fileName =
    do  offsetString <- readWritableFile
        pure $ Just (read offsetString)
    `catch` \(e :: IOException) -> do
        putLog $ show e
        pure Nothing
  where
    readWritableFile = openFile fileName ReadWriteMode >>= hGetContents

saveOffset :: FilePath -> Int -> IO ()
saveOffset fileName offset = writeFile fileName (show offset)

untilRight :: IO (Either e a) -> (e -> IO ()) -> IO a
untilRight body handler = do
    res <- body
    case res of
        Left e -> do
            handler e
            untilRight body handler
        Right a ->
            pure a

readCommand :: Text -> Maybe String
readCommand messageText =
    if (Text.length messageText > 1)
      then
        if (Text.head slashCommand == '/')
          then Just (Text.unpack (Text.tail slashCommand))
          else Nothing
      else Nothing
  where slashCommand = Text.takeWhile (not . isSpace) messageText
