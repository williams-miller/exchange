'''
DESCRIPTION
Add proxy support.
'''
import requests.adapters
from exchangelib.protocol import BaseProtocol

class ProxyAdapter(requests.adapters.HTTPAdapter):
    def send(self, *args, **kwargs):
        kwargs['proxies'] = {
            'http': 'http://10.10.0.1:12345',
            'https': 'http://10.0.0.1:54321',
        }
        return super().send(*args, **kwargs)

# Use this adapter class instead of the default
BaseProtocol.HTTP_ADAPTER_CLS = ProxyAdapter
