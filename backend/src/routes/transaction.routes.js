import { Router } from 'express';
import transactionController from '../controllers/transaction.controller.js';
import authenticate from '../middlewares/auth.js';

const router = Router();

router.use(authenticate);

router.get('/', transactionController.list);
router.get('/:id', transactionController.get);
router.post('/', transactionController.create);
router.patch('/:id', transactionController.update);
router.delete('/:id', transactionController.remove);

export default router;
