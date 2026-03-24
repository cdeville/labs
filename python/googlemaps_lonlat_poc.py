import os
import requests
import hmac
import hashlib
import base64
from urllib.parse import urlparse, urlencode
from shared_libs import get_secret

"""
Proof of concept code to get longitude and latitude from the Google Maps API

This is NOT production ready code and is only intended to demonstrate how to use the Google Maps API with Premium Plan credentials to geocode a US street address.
"""

def sign_url(url, secret):
    """Sign a URL with your cryptographic key"""
    # Decode the private key from base64 (URL-safe)
    decoded_key = base64.urlsafe_b64decode(secret)
    
    # Parse the URL to get the path and query
    parsed_url = urlparse(url)
    url_to_sign = parsed_url. path + "?" + parsed_url.query
    
    # Create HMAC-SHA1 signature
    signature = hmac.new(decoded_key, url_to_sign.encode('utf-8'), hashlib.sha1)
    
    # Encode signature as URL-safe base64
    encoded_signature = base64.urlsafe_b64encode(signature.digest()).decode('utf-8')
    
    return encoded_signature

def geocode_address(address, client_id, crypto_key):
    """
    Geocode a US street address using Google Maps Geocoding API with Premium Plan credentials
    
    Args:
        address: Street address string
        client_id:  Your Premium Plan client ID (starts with 'gme-')
        crypto_key: Your cryptographic key (base64 encoded)
    
    Returns:
        Dictionary with latitude, longitude, and formatted_address
    """
    base_url = 'https://maps.googleapis.com/maps/api/geocode/json'
    
    # Build parameters
    params = {
        'address': address,
        'client': client_id
    }
    
    # Build unsigned URL
    unsigned_url = f"{base_url}?{urlencode(params)}"
    
    # Sign the URL
    signature = sign_url(unsigned_url, crypto_key)
    
    # Add signature to final request
    params['signature'] = signature
    
    # Make the request
    response = requests.get(base_url, params=params)
    data = response.json()
    
    # Check for errors
    if data['status'] == 'OK' and len(data['results']) > 0:
        location = data['results'][0]['geometry']['location']
        return {
            'latitude': location['lat'],
            'longitude': location['lng'],
            'formatted_address': data['results'][0]['formatted_address']
        }
    else:
        error_msg = data.get('error_message', 'No error message provided')
        raise Exception(f"Geocoding failed: {data['status']} - {error_msg}")

# Usage
if __name__ == "__main__": 
    # Google Map API credentials 
    client_id = get_secret(os.environ.get("GOOGLE_CLIENTID"))
    crypto_key = get_secret(os.environ.get("GOOGLE_KEY"))
    
    # Address to geocode
    address = '1600 Amphitheatre Parkway, Mountain View, CA'
    
    try:
        result = geocode_address(address, client_id, crypto_key)
        print(f"Address: {result['formatted_address']}")
        print(f"Latitude: {result['latitude']}")
        print(f"Longitude: {result['longitude']}")
    except Exception as e:
        print(f"Error: {e}")
