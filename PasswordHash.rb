# Password Hashing With PBKDF2 (http://crackstation.net/hashing-security.htm).
# Copyright (c) 2013, Taylor Hornby
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without 
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, 
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation 
# and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE 
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
# POSSIBILITY OF SUCH DAMAGE.

require 'securerandom'
require 'openssl'
require 'base64'

# Salted password hashing with PBKDF2-SHA1.
# Authors: @RedragonX (dicesoft.net), havoc AT defuse.ca 
# www: http://crackstation.net/hashing-security.htm
module PasswordHash

  # The following constants can be changed without breaking existing hashes.
  PBKDF2_ITERATIONS = 32000
  SALT_BYTE_SIZE = 24
  HASH_BYTE_SIZE = 24

  HASH_SECTIONS = 5
  SECTION_DELIMITER = ':'
  ITERATIONS_INDEX = 1
  HASH_SIZE_INDEX = 2
  SALT_INDEX = 3
  HASH_INDEX = 4

  # Returns a salted PBKDF2 hash of the password.
  # format: algorithm:iterations:hashSize:salt:hash
  def self.createHash( password )
    salt = SecureRandom.random_bytes( SALT_BYTE_SIZE )
    pbkdf2 = OpenSSL::PKCS5::pbkdf2_hmac_sha1(
      password,
      salt,
      PBKDF2_ITERATIONS,
      HASH_BYTE_SIZE
    )

    parts = [
      "sha1",
      PBKDF2_ITERATIONS,
      pbkdf2.bytesize(),
      Base64.strict_encode64( salt ),
      Base64.strict_encode64( pbkdf2 )
    ]

    return parts.join( SECTION_DELIMITER )
  end

  # Checks if a password is correct given a hash of the correct one.
  # correctHash must be a hash string generated with createHash.
  def self.validatePassword( password, correctHash )
    params = correctHash.split( SECTION_DELIMITER )
    return false if params.length != HASH_SECTIONS

    begin
      pbkdf2 = Base64.strict_decode64( params[HASH_INDEX] )
      salt = Base64.strict_decode64( params[SALT_INDEX] )
    rescue ArgumentError
      return false
    end
    return false if pbkdf2.bytesize() != params[HASH_SIZE_INDEX].to_i

    testHash = OpenSSL::PKCS5::pbkdf2_hmac_sha1(
      password,
      salt,
      params[ITERATIONS_INDEX].to_i,
      pbkdf2.length
    )

    return slow_equals(pbkdf2, testHash)
  end

  def self.slow_equals(a, b)
    cmp = b.bytes.to_a
    result = 0
    a.bytes.each_with_index {|c,i|
      result |= c ^ cmp[i]
    }
    result == 0
  end

  # Run tests to ensure the module is functioning properly.
  # Returns true if all tests succeed, false if not.
  def self.runSelfTests
    puts "Sample hashes:"
    3.times { puts createHash("password") }

    puts "\nRunning Ruby self tests..."
    @@allPass = true

    correctPassword = 'aaaaaaaaaa'
    wrongPassword = 'aaaaaaaaab'
    hash = createHash(correctPassword)

    assert( validatePassword( correctPassword, hash ) == true, "correct password" )
    assert( validatePassword( wrongPassword, hash ) == false, "wrong password" )

    h1 = hash.split( SECTION_DELIMITER )
    h2 = createHash( correctPassword ).split( SECTION_DELIMITER )
    assert( h1[HASH_INDEX] != h2[HASH_INDEX], "different hashes" )
    assert( h1[SALT_INDEX] != h2[SALT_INDEX], "different salt" )

    if @@allPass
      puts "*** ALL TESTS PASS ***"
    else
      puts "*** FAILURES ***"
    end

    return @@allPass
  end

  def self.assert( truth, msg )
    if truth
      puts "PASS [#{msg}]"
    else
      puts "FAIL [#{msg}]"
      @@allPass = false
    end
  end

end

if __FILE__ == $0
  PasswordHash.runSelfTests
end

