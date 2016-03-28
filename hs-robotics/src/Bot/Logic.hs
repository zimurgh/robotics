module Bot.Logic
  ( calibrateMAX
  , calibrateAVG
  , maybeTurn
  , followLineWith
  , readSensor
  , rotateMotor 
  , getScaledValue 
  ) where


import Control.Monad
import Control.Monad.IO.Class
import Robotics.NXT
import Bot.Logger


calibrateMAX :: InputPort -> Int -> NXT ScaledValue
calibrateMAX port n = do
    setInputModeConfirm Three LightActive PctFullScaleMode
    lst <- replicateM n (getInputValues port)
    let threshold = (foldr1 max (map getScaledValue lst))
    return threshold


calibrateAVG :: InputPort -> Int -> NXT ScaledValue
calibrateAVG port n = do
    lst <- replicateM n (readSensor port LightActive PctFullScaleMode)
    let threshold = (foldr1 (+) lst) `div` n
    return threshold


rotateMotor :: OutputPort -> OutputPower -> NXT ()
rotateMotor port power =
    setOutputStateConfirm port power modes regMode 0 motorRunState 0
  where modes = [MotorOn, Brake,Regulated]
        regMode = RegulationModeIdle 
        motorRunState = MotorRunStateRunning


getScaledValue :: InputValue -> ScaledValue
getScaledValue (InputValue _ _ _ _ _ _ _ x _) = x


readSensor :: InputPort -> SensorType -> SensorMode -> NXT ScaledValue
readSensor port sType sMode = do
  setInputModeConfirm port sType sMode
  reading <- fmap getScaledValue $ getInputValues port
  resetInputScaledValue port
  return reading

maybeTurn :: Logger -> Int -> Int -> Int -> Int -> NXT ()
maybeTurn logger threshold1 threshold2 readingLeft readingRight
  -- | ((abs (45 - readingLeft)) < 3) || ((abs (45 - readingRight)) < 2) = do
  --    liftIO $ writeTo logger Debug $ "Stopping"
  --     stopEverything
  | abs (readingLeft - readingRight) < 2 = do
      rotateMotor A 25
      rotateMotor B 25
  | abs (readingLeft - readingRight) > 2 = do
    if readingLeft > readingRight
      then do
        -- Right side is detecting the line
        liftIO $ writeTo logger Debug $ "--> Turn Right"
        rotateMotor A 30
        rotateMotor B 26
      else do
        -- Left side is detecting the line
        liftIO $ writeTo logger Debug $ "--> Turn Left"
        rotateMotor A 26
        rotateMotor B 30
  | otherwise = return ()


followLineWith :: Logger -> ScaledValue -> ScaledValue -> NXT ()
followLineWith logger threshold1 threshold2 = do
    reading1 <- calibrateAVG Three 10
    reading2 <- calibrateAVG Four 10
    liftIO $ writeTo logger Debug $ "Right Reading is: " ++ show reading1
    liftIO $ writeTo logger Debug $ "Left Reading is: " ++ show reading2
    maybeTurn logger threshold1 threshold2 reading1 reading2 
