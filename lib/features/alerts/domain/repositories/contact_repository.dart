import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/contact_entity.dart';

abstract class ContactRepository {
  Future<Either<Failure, ContactEntity>> addContact(ContactEntity contact);
  
  Future<Either<Failure, void>> updateContact(ContactEntity contact);
  
  Future<Either<Failure, void>> deleteContact(String contactId);
  
  Future<Either<Failure, List<ContactEntity>>> getContacts(String userId);
  
  Future<Either<Failure, ContactEntity?>> getEmergencyContact(String userId);
  
  Future<Either<Failure, void>> verifyContact(String contactId);
  
  Future<Either<Failure, void>> setEmergencyContact(String contactId);
}
