defmodule CHAT.ASN1 do

  def dir(), do: :application.get_env(:ca, :bundle, "priv/apple/")

  def emitSequenceDefinition(name,fields,ctor,decoder,encoder) do
"""
import Foundation
import SwiftASN1
import Crypto

@usableFromInline struct #{name}: DERImplicitlyTaggable, Hashable, Sendable {
    @inlinable static var defaultIdentifier: ASN1Identifier { .sequence }
#{fields}
    #{ctor}
    #{decoder}
    #{encoder}
}
"""
  end

  def parseFieldType(fieldType) when is_atom(fieldType), do: "#{fieldType}"
  def parseFieldType({:ANY_DEFINED_BY, fieldType}) when is_atom(fieldType), do: "#{fieldType}"
  def parseFieldType({:contentType, {:Externaltypereference,_,moduleFile, fieldType}}), do: "#{fieldType}"
  def parseFieldType({:Externaltypereference,_,moduleFile, fieldType}), do: "#{fieldType}"

  def parseFieldName({:contentType, {:Externaltypereference,_,moduleFile, fieldName}}), do: "#{fieldName}"
  def parseFieldName(fieldName), do: "#{fieldName}"

  def emitFields(pad, fields) when is_list(fields) do
      Enum.join(:lists.map(fn 
       {:ComponentType,_,fieldName,{:type,_,fieldType,[],[],:no},optional,_,_} ->
         String.duplicate(" ", pad) <> emitSequenceElement(parseFieldName(fieldName), substituteType(parseFieldType(fieldType)))
      end, fields), "")
  end


  def substituteType("INTEGER"), do: "ArraySlice<UInt8>"
  def substituteType(t), do: t

#            let r = try ArraySlice<UInt8>(derEncoded: &nodes)

  def emitDecoderBodyElement(name, type), do: "let #{name} = try #{type}(derEncoded: &nodes)"
  def emitEncoderBodyElement(name),       do: "try coder.serialize(self.#{name})"
  def emitCtorBodyElement(name),          do: "self.#{name} = #{name}"
  def emitCtorParam(name, type),          do: "#{name}: #{type}"
  def emitArg(name),                      do: "#{name}: #{name}"
  def emitSequenceElement(name, type),    do: "@usableFromInline var #{name}: #{type}\n"

  def emitSequenceDecoder(fields, name, args), do:
"""
@inlinable init(derEncoded root: ASN1Node, withIdentifier identifier: ASN1Identifier) throws {
        self = try DER.sequence(root, identifier: identifier) { nodes in
#{fields}
            return #{normalizeName(name)}(#{args})
        }
    }
"""

  def emitSequenceEncoder(fields), do:
"""
@inlinable func serialize(into coder: inout DER.Serializer, withIdentifier identifier: ASN1Identifier) throws {
        try coder.appendConstructedNode(identifier: identifier) { coder in
#{fields}
        }
    }
"""

  def emitCtor(params,fields), do:
"""
@inlinable init(#{params}) {
#{fields}
    }
"""

  def emitCtorBody(fields), do:
      Enum.join(:lists.map(fn 
       {:ComponentType,_,fieldName,{:type,_,fieldType,[],[],:no},optional,_,_} ->
         String.duplicate(" ", 8) <> emitCtorBodyElement(parseFieldName(fieldName))
      end, fields), "\n")

  def emitEncoderBody(fields), do:
      Enum.join(:lists.map(fn 
       {:ComponentType,_,fieldName,{:type,_,fieldType,[],[],:no},optional,_,_} ->
         String.duplicate(" ", 12) <> emitEncoderBodyElement(parseFieldName(fieldName))
      end, fields), "\n")

  def emitDecoderBody(fields), do:
      Enum.join(:lists.map(fn 
       {:ComponentType,_,fieldName,{:type,_,fieldType,[],[],:no},optional,_,_} ->
         String.duplicate(" ", 12) <> emitDecoderBodyElement(parseFieldName(fieldName), substituteType(parseFieldType(fieldType)))
      end, fields), "\n")

  def emitParams(fields) when is_list(fields) do
      Enum.join(:lists.map(fn 
       {:ComponentType,_,fieldName,{:type,_,fieldType,[],[],:no},optional,_,_} ->
         emitCtorParam(parseFieldName(fieldName), substituteType(parseFieldType(fieldType)))
      end, fields), ", ")
  end

  def emitArgs(fields) when is_list(fields) do
      Enum.join(:lists.map(fn 
       {:ComponentType,_,fieldName,{:type,_,fieldType,[],[],:no},optional,_,_} ->
         emitArg(parseFieldName(fieldName))
      end, fields), ", ")
  end

  def compile_all() do
      {:ok, files} = :file.list_dir dir()
      :lists.map(fn file ->
         parse(dir() <> :erlang.list_to_binary(file))
      end, files)
      :ok
  end

  def compileType(pos, name, typeDefinition) do
      case typeDefinition do
           {:type, _, :"OBJECT IDENTIFIER", _, _, :no} -> 
               :skip
           {:type, _, {typeASN1, _, _, _, fields}, _, _, :no} -> 
               :io.format 'args: ~p', [fields]
               res = case typeASN1 do
                 :SEQUENCE -> emitSequenceDefinition(normalizeName(name), emitFields(4, fields), emitCtor(emitParams(fields),emitCtorBody(fields)),
                       emitSequenceDecoder(emitDecoderBody(fields), name, emitArgs(fields)), emitSequenceEncoder(emitEncoderBody(fields)) )
                 _ -> :logger.info('ASN.1 type ~p is not supported.', [typeASN1])
               end
               file = normalizeName(name)
               :file.write_file file <> ".swift", res
      end 
  end

  def normalizeName(name), do: Enum.join(String.split("#{name}", "-"), "")

  def dumpValue(pos, name, type, value, mod) do
      :logger.info 'value ~p', [type]
      :logger.info 'value name: ~p', [name]
      :logger.info 'value value: ~p', [value]
      :logger.info 'value mod: ~p', [mod]
      :logger.info 'value pos: ~p', [pos]
  end

  def dumpClass(pos, name, mod, type) do
      :logger.info 'class ~p', [type]
      :logger.info 'class name: ~p', [name]
      :logger.info 'class mod: ~p', [mod]
      :logger.info 'class pos: ~p', [pos]
  end

  def dumpPType(pos, name, args, type) do
      :logger.info 'ptype ~p', [type]
      :logger.info 'ptype name: ~p', [name]
      :logger.info 'ptype args: ~p', [args]
      :logger.info 'ptype pos: ~p', [pos]
  end

  def dumpModule(pos, name, defid, tagdefault, exports, imports) do
      :logger.info 'module pos: ~p', [pos]
      :logger.info 'module name: ~p', [name]
      :logger.info 'module defid: ~p', [defid]
      :logger.info 'module tagdefault: ~p', [tagdefault]
      :logger.info 'module exports: ~p', [exports]
      :logger.info 'module imports: ~p', [imports]
  end

  def parse(file \\ "priv/proto/CHAT.asn1") do
      tokens = :asn1ct_tok.file file
      {:ok, mod} = :asn1ct_parser2.parse file, tokens
      :io.format '~p~n', [mod]
      {:module, pos, name, defid, tagdefault, exports, imports, _, typeorval} = mod
      :lists.map(fn
         {:typedef,  _, pos, name, type} -> compileType(pos, name, type)
         {:ptypedef, _, pos, name, args, type} -> dumpPType(pos, name, args, type)
         {:classdef, _, pos, name, mod, type} -> dumpClass(pos, name, mod, type)
         {:valuedef, _, pos, name, type, value, mod} -> dumpValue(pos, name, type, value, mod)
      end, typeorval)
      dumpModule(pos, name, defid, tagdefault, exports, imports)
  end

end
