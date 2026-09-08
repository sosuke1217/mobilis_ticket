require "openssl"
require "securerandom"

class TotpService
  ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
  INTERVAL = 30

  def self.generate_secret(bytes: 20)
    encode_base32(SecureRandom.random_bytes(bytes))
  end

  def self.provisioning_uri(secret:, account:, issuer: "Mobilis")
    label = ERB::Util.url_encode("#{issuer}:#{account}")
    query = URI.encode_www_form(secret: secret, issuer: issuer, algorithm: "SHA1", digits: 6, period: INTERVAL)
    "otpauth://totp/#{label}?#{query}"
  end

  def self.valid?(secret, code, at: Time.current, drift: 1)
    normalized = code.to_s.gsub(/\s+/, "")
    return false unless normalized.match?(/\A\d{6}\z/)

    current_step = at.to_i / INTERVAL
    (-drift..drift).any? do |offset|
      ActiveSupport::SecurityUtils.secure_compare(generate_code(secret, current_step + offset), normalized)
    end
  end

  def self.generate_code(secret, step = Time.current.to_i / INTERVAL)
    digest = OpenSSL::HMAC.digest("SHA1", decode_base32(secret), [step].pack("Q>"))
    offset = digest.getbyte(-1) & 0x0f
    number = digest.byteslice(offset, 4).unpack1("N") & 0x7fffffff
    format("%06d", number % 1_000_000)
  end

  def self.encode_base32(value)
    bits = value.bytes.map { |byte| format("%08b", byte) }.join
    bits.scan(/.{1,5}/).map { |chunk| ALPHABET[chunk.ljust(5, "0").to_i(2)] }.join
  end

  def self.decode_base32(value)
    bits = value.to_s.upcase.delete("= ").chars.map do |character|
      index = ALPHABET.index(character)
      raise ArgumentError, "Invalid Base32 secret" unless index

      format("%05b", index)
    end.join
    bits.scan(/.{8}/).map { |chunk| chunk.to_i(2) }.pack("C*")
  end

  private_class_method :encode_base32, :decode_base32
end
