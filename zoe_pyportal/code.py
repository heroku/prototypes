from adafruit_esp32spi import adafruit_esp32spi, adafruit_esp32spi_wifimanager
from adafruit_pyportal import PyPortal
import board
import busio
from digitalio import DigitalInOut
import gc
import random
import time

from secrets import secrets

spi = busio.SPI(board.SCK, board.MOSI, board.MISO)
esp = adafruit_esp32spi.ESP_SPIcontrol(
    spi,
    DigitalInOut(board.ESP_CS),
    DigitalInOut(board.ESP_BUSY),
    DigitalInOut(board.ESP_RESET)
)
pyportal = PyPortal(
    esp=esp,
    external_spi=spi,
)
wifi = adafruit_esp32spi_wifimanager.ESPSPI_WiFiManager(esp, secrets)

def fetch_access_token():
    print("Fetching access token.")
    access_token = None
    while not access_token:
        try:
            response = wifi.post(
                "https://www.googleapis.com/oauth2/v4/token",
                json = {
                    "client_id":        secrets['google_client_id'],
                    "client_secret":    secrets['google_client_secret'],
                    "grant_type":       "refresh_token",
                    "refresh_token":    secrets['google_refresh_token']
                }
            )
            access_token = response.json()['access_token']
        except (KeyError, RuntimeError, ValueError) as e:
            print("Some error occured, retrying! -", e)
    print("Fetched access token.")
    return access_token

def fetch_photos():
    access_token = fetch_access_token()

    print("Fetching photos.")
    photos = None
    while not photos:
        try:
            response = wifi.post(
                "https://photoslibrary.googleapis.com/v1/mediaItems:search?prettyPrint=false",
                headers = {
                    'Authorization': 'Bearer ' + access_token
                },
                json = {
                    "albumId":      secrets['google_photos_shared_album_id'],
                    "pageSize":     6
                },
                timeout = 0
            )
            photos = response.json()['mediaItems']
            response.close()
        except (KeyError, RuntimeError, ValueError) as e:
            print("Some error occured, retrying! -", e)
    print("Fetched photos.")
    return photos

def randomize_background():
    photos = fetch_photos()
    index = random.randrange(0, 5)
    image_url = photos[index]['baseUrl'] + "=w320-h240"
    try:
        print("Converting photo.")
        image_url = pyportal.image_converter_url(image_url, 320, 240)
        # convert image to bitmap and cache
        #print("**not actually wgetting**")
        filename = "/cache.bmp"
        chunk_size = 12000      # default chunk size is 12K (for QSPI)
        if pyportal._sdcard:
            filename = "/sd" + filename
            chunk_size = 512  # current bug in big SD writes -> stick to 1 block
        try:
            pyportal.wget(image_url, filename, chunk_size=chunk_size)
        except OSError as error:
            print(error)
            raise OSError("""\n\nNo writable filesystem found for saving datastream. Insert an SD card or set internal filesystem to be unsafe by setting 'disable_concurrent_write_protection' in the mount options in boot.py""") # pylint: disable=line-too-long
        except RuntimeError as error:
            print(error)
            raise RuntimeError("wget didn't write a complete file")
        print("Coverted photo.")
        pyportal.set_background(filename, pyportal._image_position)
    except ValueError as error:
        print("Error displaying cached image. " + error.args[0])
        pyportal.set_background(self._default_bg)
    finally:
        image_url = None
        gc.collect()

while True:
    try:
        randomize_background()
    except (KeyError, RuntimeError, ValueError) as e:
        print("Some error occured, retrying! -", e)

    time.sleep(60)
