# SubZero Vanity Market Request Contract

Smart contract for managing vanity address requests and refunds in the SubZero Vanity Market system.

## Events

### NewRequest
Emitted when a new vanity address request is created
- `owner`: Address of the request creator
- `unlock_delay`: Time delay required before requesting a refund
- `relevant_bits_mask`: Bit mask specifying which bits of the address matter
- `desired_bits`: Desired bit pattern for the vanity address
- `value_added`: Amount of ETH added to the request reward

### InitiatedUnlock
Emitted when request owner starts the refund process
- `request_key`: Unique identifier of the request

### Unlocked
Emitted when funds are successfully refunded to the requester
- `request_key`: Unique identifier of the request

### RequestFilled
Emitted when a request is fulfilled with a matching vanity address
- `request_key`: Unique identifier of the fulfilled request

## External Methods

### request
Creates or adds funds to a vanity address request
- **Parameters:**
  - `unlock_delay`: Safety period before funds can be refunded if request isn't fulfilled
  - `relevant_bits_mask`: Bit mask indicating which address bits to match
  - `desired_bits`: Desired bit pattern for the address
- **Payable:** Yes - Payment adds to request reward

### initiate_unlock
Starts the countdown for refunding funds if request wasn't fulfilled
- **Parameters:**
  - `unlock_delay`: Original safety period
  - `relevant_bits_mask`: Original bit mask
  - `desired_bits`: Original desired bits
- **Requirements:** Request must exist and not be in refund process

### unlock
Claims refund after safety period if request wasn't fulfilled
- **Parameters:**
  - `unlock_delay`: Original safety period
  - `relevant_bits_mask`: Original bit mask
  - `desired_bits`: Original desired bits
- **Requirements:** Safety period must have elapsed since initiating refund

### fulfill
Fulfills a request by minting a matching vanity address
- **Parameters:**
  - `requester`: Address of the request creator
  - `unlock_delay`: Original safety period
  - `relevant_bits_mask`: Original bit mask
  - `desired_bits`: Original desired bits
  - `id`: Token ID for minting
  - `nonce`: Nonce for address generation
- **Requirements:** Generated address must match request criteria
- **Note:** If fulfilled, reward goes to fulfiller and vanity address is minted to requester

### get_request
Retrieves request details
- **Parameters:**
  - `owner`: Address of request creator
  - `unlock_delay`: Safety period before refund
  - `relevant_bits_mask`: Bit mask
  - `desired_bits`: Desired bits
- **Returns:** Request struct with reward amount and refund initiation timestamp
